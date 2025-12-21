# Coolify v5.x Docker Image
# Multi-stage build for optimal image size

# Stage 1: Build frontend assets
FROM oven/bun:1 AS frontend-builder

WORKDIR /app

# Copy package files
COPY package.json bun.lock ./

# Install dependencies
RUN bun install --frozen-lockfile

# Copy source files needed for build
COPY resources/ ./resources/
COPY vite.config.ts ./

# Build frontend assets
RUN bun run build

# Stage 2: Install PHP dependencies
# Using PHP 8.4 (stable) - PHP 8.5 RC has extension build issues
# Update to 8.5 when stable release is available
FROM php:8.4-cli-alpine AS composer-builder

# Install composer and required extensions
RUN apk add --no-cache git unzip curl \
    && curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer

WORKDIR /app

# Copy composer files
COPY composer.json composer.lock ./

# Install dependencies without dev packages
RUN composer install \
    --no-dev \
    --no-interaction \
    --no-progress \
    --no-scripts \
    --prefer-dist \
    --optimize-autoloader \
    --ignore-platform-reqs

# Stage 3: Final production image
# Using PHP 8.4 (stable) - PHP 8.5 RC has extension build issues
# Update to 8.5 when stable release is available
FROM php:8.4-fpm-alpine AS production

# Install system dependencies
RUN apk add --no-cache \
    curl \
    git \
    libpq \
    libpng \
    libjpeg-turbo \
    libwebp \
    freetype \
    icu-libs \
    oniguruma \
    libzip \
    linux-headers \
    supervisor \
    nginx \
    redis

# Install build dependencies and PHP extensions
RUN apk add --no-cache --virtual .build-deps \
    postgresql-dev \
    libpng-dev \
    libjpeg-turbo-dev \
    libwebp-dev \
    freetype-dev \
    icu-dev \
    oniguruma-dev \
    libzip-dev \
    $PHPIZE_DEPS

# Configure and install GD extension
RUN docker-php-ext-configure gd \
    --with-freetype \
    --with-jpeg \
    --with-webp

# Install PHP extensions (separately to handle PHP 8.5 compatibility)
RUN docker-php-ext-install pdo pdo_pgsql pgsql gd intl zip opcache pcntl

# Install Redis extension via PECL
RUN pecl install redis && docker-php-ext-enable redis

# Cleanup build dependencies
RUN apk del .build-deps && rm -rf /tmp/* /var/cache/apk/*

# Configure PHP
RUN mv "$PHP_INI_DIR/php.ini-production" "$PHP_INI_DIR/php.ini"

# PHP configuration
COPY docker/php.ini /usr/local/etc/php/conf.d/99-coolify.ini

# Nginx configuration
COPY docker/nginx.conf /etc/nginx/nginx.conf
COPY docker/default.conf /etc/nginx/http.d/default.conf

# Supervisor configuration
COPY docker/supervisord.conf /etc/supervisor/conf.d/supervisord.conf

# Create application directory
WORKDIR /var/www/html

# Copy application code
COPY --chown=www-data:www-data . .

# Copy vendor from composer builder
COPY --from=composer-builder --chown=www-data:www-data /app/vendor ./vendor

# Copy built frontend assets
COPY --from=frontend-builder --chown=www-data:www-data /app/public/build ./public/build

# Create required directories
RUN mkdir -p \
    storage/app/public \
    storage/framework/cache/data \
    storage/framework/sessions \
    storage/framework/views \
    storage/logs \
    bootstrap/cache \
    /var/log/supervisor \
    /var/log/nginx \
    && chown -R www-data:www-data storage bootstrap/cache \
    && chmod -R 775 storage bootstrap/cache

# Copy entrypoint script
COPY docker/entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

# Expose port
EXPOSE 80

# Health check
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD curl -f http://localhost/up || exit 1

# Start application
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]
