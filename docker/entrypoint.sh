#!/bin/sh
set -e

cd /var/www/html

echo "Starting Coolify initialization..."

# Ensure proper ownership of application directory
chown -R www-data:www-data /var/www/html 2>/dev/null || true

# Install composer dependencies if vendor directory is missing or empty
if [ ! -f "/var/www/html/vendor/autoload.php" ]; then
    echo "Installing composer dependencies..."
    if [ "$APP_ENV" = "production" ]; then
        composer install --no-dev --no-interaction --no-progress --prefer-dist --optimize-autoloader --ignore-platform-reqs
    else
        composer install --no-interaction --no-progress --prefer-dist --optimize-autoloader --ignore-platform-reqs
    fi
fi

# Create .env file from environment variables if it doesn't exist
if [ ! -f "/var/www/html/.env" ]; then
    echo "Creating .env file from environment variables..."
    cat > /var/www/html/.env << EOF
APP_NAME=${APP_NAME:-Coolify}
APP_ENV=${APP_ENV:-production}
APP_DEBUG=${APP_DEBUG:-false}
APP_URL=${APP_URL:-http://localhost}
APP_KEY=${APP_KEY:-}

DB_CONNECTION=${DB_CONNECTION:-pgsql}
DB_HOST=${DB_HOST:-coolify-db}
DB_PORT=${DB_PORT:-5432}
DB_DATABASE=${DB_DATABASE:-coolify}
DB_USERNAME=${DB_USERNAME:-coolify}
DB_PASSWORD=${DB_PASSWORD:-}

REDIS_HOST=${REDIS_HOST:-coolify-redis}
REDIS_PASSWORD=${REDIS_PASSWORD:-}
REDIS_PORT=${REDIS_PORT:-6379}

CACHE_STORE=${CACHE_STORE:-redis}
SESSION_DRIVER=${SESSION_DRIVER:-redis}
QUEUE_CONNECTION=${QUEUE_CONNECTION:-redis}

LOG_CHANNEL=${LOG_CHANNEL:-stack}
LOG_LEVEL=${LOG_LEVEL:-debug}

APP_MAINTENANCE_DRIVER=${APP_MAINTENANCE_DRIVER:-file}
APP_MAINTENANCE_STORE=${APP_MAINTENANCE_STORE:-redis}
EOF
    chown www-data:www-data /var/www/html/.env
fi

# Wait for database to be ready
echo "Waiting for database connection..."
max_tries=30
tries=0
until php -r "new PDO('pgsql:host=${DB_HOST};dbname=${DB_DATABASE}', '${DB_USERNAME}', '${DB_PASSWORD}');" 2>/dev/null; do
    tries=$((tries + 1))
    if [ $tries -ge $max_tries ]; then
        echo "Database connection timeout. Continuing anyway..."
        break
    fi
    echo "Database is not ready yet. Waiting... ($tries/$max_tries)"
    sleep 2
done
echo "Database connection established!"

# Generate application key if not set
if [ -z "$APP_KEY" ] || [ "$APP_KEY" = "" ]; then
    echo "Generating application key..."
    php /var/www/html/artisan key:generate --force
    # Re-read the .env to get the new key
    export APP_KEY=$(grep '^APP_KEY=' /var/www/html/.env | cut -d'=' -f2)
fi

# Clear any previous cache
echo "Clearing old caches..."
php /var/www/html/artisan config:clear || true
php /var/www/html/artisan route:clear || true
php /var/www/html/artisan view:clear || true

# Cache configurations
echo "Optimizing application..."
php /var/www/html/artisan config:cache || true
php /var/www/html/artisan route:cache || true
php /var/www/html/artisan view:cache || true

# Run database migrations
echo "Running database migrations..."
php /var/www/html/artisan migrate --force || true

# Create storage link if it doesn't exist
if [ ! -L "/var/www/html/public/storage" ]; then
    echo "Creating storage link..."
    php /var/www/html/artisan storage:link || true
fi

# Ensure proper permissions
chown -R www-data:www-data /var/www/html/storage /var/www/html/bootstrap/cache
chmod -R 775 /var/www/html/storage /var/www/html/bootstrap/cache

echo "Coolify initialization complete!"

# Execute the main command
exec "$@"
