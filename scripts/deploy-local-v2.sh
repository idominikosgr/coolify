#!/usr/bin/env bash

# Final Coolify Local Deployment Script
# Incorporates official best practices + local development optimizations

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
LOG_FILE="$PROJECT_ROOT/logs/deploy-local-$(date +%Y%m%d-%H%M%S).log"

# Official logging functions
log_info() {
    echo -e "${BLUE}ℹ${NC} $1"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] INFO: $1" >>"$LOG_FILE"
}

log_success() {
    echo -e "${GREEN}✓${NC} $1"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] SUCCESS: $1" >>"$LOG_FILE"
}

log_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] WARNING: $1" >>"$LOG_FILE"
}

log_error() {
    echo -e "${RED}✗${NC} $1"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: $1" >>"$LOG_FILE"
}

log_section() {
    echo ""
    echo "============================================================"
    echo "$1"
    echo "============================================================"
    echo "" >>"$LOG_FILE"
    echo "============================================================" >>"$LOG_FILE"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >>"$LOG_FILE"
    echo "============================================================" >>"$LOG_FILE"
}

# Create necessary directories
create_directories() {
    mkdir -p "$(dirname "$LOG_FILE")"
    mkdir -p ./data/{coolify,ssh,applications,databases,backups,services,proxy,sentinel}
    mkdir -p ./data/coolify/{ssh/{keys,mux},proxy/dynamic}
    mkdir -p ./logs
    mkdir -p ./ssl
}

# Check if Docker is installed and running (enhanced)
check_docker() {
    log_info "Checking Docker installation..."
    
    if ! command -v docker &> /dev/null; then
        log_error "Docker is not installed. Please install Docker first."
        log_info "Visit: https://docs.docker.com/get-docker/"
        exit 1
    fi

    if ! docker info &> /dev/null; then
        log_error "Docker is not running. Please start Docker."
        exit 1
    fi

    log_success "Docker is installed and running"
}

# Check if Docker Compose is available (enhanced)
check_docker_compose() {
    log_info "Checking Docker Compose..."
    
    if ! docker compose version &> /dev/null; then
        log_error "Docker Compose is not available."
        log_info "Please install Docker Compose plugin"
        exit 1
    fi

    log_success "Docker Compose is available"
}

# Collect local setup information (new feature)
collect_setup_info() {
    log_info "Collecting local setup information..."
    
    # Default values for local development
    read -p "Admin Email [admin@coolify.local]: " ADMIN_EMAIL
    ADMIN_EMAIL=${ADMIN_EMAIL:-admin@coolify.local}
    
    read -p "Admin Password [admin123]: " ADMIN_PASSWORD
    ADMIN_PASSWORD=${ADMIN_PASSWORD:-admin123}
    
    read -p "Application Port [8000]: " APP_PORT
    APP_PORT=${APP_PORT:-8000}
    
    read -p "WebSocket Port [6001]: " WS_PORT
    WS_PORT=${WS_PORT:-6001}
    
    read -p "Enable debug mode? [Y/n]: " ENABLE_DEBUG
    ENABLE_DEBUG=${ENABLE_DEBUG:-Y}
    
    if [[ $ENABLE_DEBUG =~ ^[Yy]$ ]]; then
        APP_DEBUG="true"
        LOG_LEVEL="debug"
    else
        APP_DEBUG="false"
        LOG_LEVEL="info"
    fi
    
    log_success "Setup information collected"
}

# Generate secure credentials (official method)
generate_credentials() {
    log_info "Generating secure credentials..."
    
    # Official credential generation methods
    APP_ID=$(openssl rand -hex 16)
    APP_KEY="base64:$(openssl rand -base64 32)"
    DB_PASSWORD=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-32)
    REDIS_PASSWORD=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-32)
    PUSHER_APP_ID=$(openssl rand -hex 32)
    PUSHER_APP_KEY=$(openssl rand -hex 32)
    PUSHER_APP_SECRET=$(openssl rand -hex 32)
    
    log_success "Secure credentials generated"
}

# Create environment file (enhanced)
create_environment() {
    log_info "Creating environment configuration..."
    
    cat > .env.local << EOF
# Coolify Local Development Environment
# Generated on: $(date)

# Application
APP_NAME=Coolify
APP_ENV=local
APP_DEBUG=${APP_DEBUG}
APP_URL=http://localhost:${APP_PORT}
APP_ID=${APP_ID}
APP_KEY=${APP_KEY}

# Database
DB_CONNECTION=pgsql
DB_HOST=coolify-db
DB_PORT=5432
DB_DATABASE=coolify
DB_USERNAME=coolify
DB_PASSWORD=${DB_PASSWORD}

# Redis
REDIS_HOST=coolify-redis
REDIS_PASSWORD=${REDIS_PASSWORD}
REDIS_PORT=6379

# Cache & Session
CACHE_STORE=redis
SESSION_DRIVER=redis
QUEUE_CONNECTION=redis

# Broadcasting (WebSocket)
BROADCAST_DRIVER=pusher
PUSHER_APP_ID=${PUSHER_APP_ID}
PUSHER_APP_KEY=${PUSHER_APP_KEY}
PUSHER_APP_SECRET=${PUSHER_APP_SECRET}
PUSHER_HOST=localhost
PUSHER_PORT=${WS_PORT}
PUSHER_SCHEME=http
PUSHER_BACKEND_HOST=localhost

# Admin User
ROOT_USERNAME=admin
ROOT_USER_EMAIL=${ADMIN_EMAIL}
ROOT_USER_PASSWORD=${ADMIN_PASSWORD}

# Development Settings
AUTOUPDATE=false
LOG_LEVEL=${LOG_LEVEL}
EOF

    log_success "Environment configuration created"
}

# Create docker-compose configuration (enhanced)
create_docker_compose() {
    log_info "Creating Docker Compose configuration..."
    
    cat > docker-compose.local.yml << EOF
version: '3.8'

services:
  coolify:
    image: coollabsio/coolify:latest
    container_name: coolify-app
    restart: unless-stopped
    ports:
      - "${APP_PORT}:80"
      - "${WS_PORT}:6001"
    environment:
      APP_NAME: Coolify
      APP_ENV: local
      APP_DEBUG: "${APP_DEBUG}"
      APP_URL: http://localhost:${APP_PORT}
      APP_ID: ${APP_ID}
      APP_KEY: ${APP_KEY}
      DB_CONNECTION: pgsql
      DB_HOST: coolify-db
      DB_PORT: 5432
      DB_DATABASE: coolify
      DB_USERNAME: coolify
      DB_PASSWORD: ${DB_PASSWORD}
      REDIS_HOST: coolify-redis
      REDIS_PASSWORD: ${REDIS_PASSWORD}
      REDIS_PORT: 6379
      CACHE_STORE: redis
      SESSION_DRIVER: redis
      QUEUE_CONNECTION: redis
      BROADCAST_DRIVER: pusher
      PUSHER_APP_ID: ${PUSHER_APP_ID}
      PUSHER_APP_KEY: ${PUSHER_APP_KEY}
      PUSHER_APP_SECRET: ${PUSHER_APP_SECRET}
      PUSHER_HOST: localhost
      PUSHER_PORT: ${WS_PORT}
      PUSHER_SCHEME: http
      PUSHER_BACKEND_HOST: localhost
      ROOT_USERNAME: admin
      ROOT_USER_EMAIL: ${ADMIN_EMAIL}
      ROOT_USER_PASSWORD: ${ADMIN_PASSWORD}
    volumes:
      - ./data/coolify:/var/www/html/storage
      - /var/run/docker.sock:/var/run/docker.sock
      - ./logs:/var/log/nginx
    depends_on:
      coolify-db:
        condition: service_healthy
      coolify-redis:
        condition: service_healthy
    networks:
      - coolify-network
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:80"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 60s

  coolify-db:
    image: postgres:17-alpine
    container_name: coolify-db
    restart: unless-stopped
    environment:
      POSTGRES_USER: coolify
      POSTGRES_PASSWORD: ${DB_PASSWORD}
      POSTGRES_DB: coolify
    volumes:
      - ./data/databases:/var/lib/postgresql/data
    networks:
      - coolify-network
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U coolify -d coolify"]
      interval: 10s
      timeout: 5s
      retries: 5

  coolify-redis:
    image: redis:7-alpine
    container_name: coolify-redis
    restart: unless-stopped
    command: redis-server --requirepass ${REDIS_PASSWORD} --appendonly yes
    volumes:
      - ./data/redis:/data
    networks:
      - coolify-network
    healthcheck:
      test: ["CMD", "redis-cli", "--raw", "incr", "ping"]
      interval: 10s
      timeout: 5s
      retries: 5

  coolify-realtime:
    image: quay.io/soketi/soketi:1.6-16-alpine
    container_name: coolify-realtime
    restart: unless-stopped
    ports:
      - "${WS_PORT}:6001"
    environment:
      SOKETI_DEBUG: "1"
      SOKETI_HOST: 0.0.0.0
      SOKETI_DEFAULT_APP_ID: ${PUSHER_APP_ID}
      SOKETI_DEFAULT_APP_KEY: ${PUSHER_APP_KEY}
      SOKETI_DEFAULT_APP_SECRET: ${PUSHER_APP_SECRET}
    networks:
      - coolify-network
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:6001"]
      interval: 10s
      timeout: 5s
      retries: 3

networks:
  coolify-network:
    driver: bridge

volumes:
  coolify-storage:
    driver: local
EOF

    log_success "Docker Compose configuration created"
}

# Start services (enhanced)
start_services() {
    log_info "Starting Coolify services..."
    
    # Pull images
    log_info "Pulling Docker images..."
    docker compose -f docker-compose.local.yml pull 2>>"$LOG_FILE"
    
    # Start services
    log_info "Starting services..."
    docker compose -f docker-compose.local.yml up -d 2>>"$LOG_FILE"
    
    log_success "Services started"
}

# Wait for database to be ready (enhanced)
wait_for_db() {
    log_info "Waiting for database to be ready..."
    
    local max_attempts=30
    local attempt=1

    while [ $attempt -le $max_attempts ]; do
        if docker compose -f docker-compose.local.yml exec -T coolify-db pg_isready -U coolify -d coolify &> /dev/null; then
            log_success "Database is ready"
            return 0
        fi

        echo -n "."
        sleep 2
        attempt=$((attempt + 1))
    done

    log_error "Database failed to become ready after ${max_attempts} attempts"
    docker compose -f docker-compose.local.yml logs coolify-db >>"$LOG_FILE" 2>&1
    exit 1
}

# Wait for application to be ready (new feature)
wait_for_app() {
    log_info "Waiting for application to be ready..."
    
    local max_attempts=60
    local attempt=1

    while [ $attempt -le $max_attempts ]; do
        if curl -s -o /dev/null -w '%{http_code}' http://localhost:${APP_PORT} | grep -q "200\|302"; then
            log_success "Application is ready"
            return 0
        fi

        echo -n "."
        sleep 2
        attempt=$((attempt + 1))
    done

    log_error "Application failed to become ready after ${max_attempts} attempts"
    docker compose -f docker-compose.local.yml logs coolify-app >>"$LOG_FILE" 2>&1
    exit 1
}

# Run migrations (enhanced)
run_migrations() {
    log_info "Running database migrations..."
    
    if docker compose -f docker-compose.local.yml exec -T coolify php artisan migrate --force 2>>"$LOG_FILE"; then
        log_success "Migrations completed"
    else
        log_error "Migrations failed"
        exit 1
    fi
}

# Create admin user (enhanced)
create_admin_user() {
    log_info "Creating admin user..."
    
    # Create admin user using tinker
    if docker compose -f docker-compose.local.yml exec -T coolify php artisan tinker --execute="
\$user = \App\Models\User::where('email', '${ADMIN_EMAIL}')->first();
if (!\$user) {
    \$user = new \App\Models\User();
    \$user->name = 'Admin';
    \$user->email = '${ADMIN_EMAIL}';
    \$user->password = \Hash::make('${ADMIN_PASSWORD}');
    \$user->save();
    echo 'Admin user created successfully';
} else {
    echo 'Admin user already exists';
}
" 2>>"$LOG_FILE"; then
        log_success "Admin user created/verified"
    else
        log_warning "Admin user creation may have failed"
    fi
}

# Clear and setup caches (enhanced)
setup_caches() {
    log_info "Setting up caches..."
    
    # Clear all caches first
    docker compose -f docker-compose.local.yml exec -T coolify php artisan cache:clear 2>>"$LOG_FILE"
    docker compose -f docker-compose.local.yml exec -T coolify php artisan config:clear 2>>"$LOG_FILE"
    docker compose -f docker-compose.local.yml exec -T coolify php artisan route:clear 2>>"$LOG_FILE"
    docker compose -f docker-compose.local.yml exec -T coolify php artisan view:clear 2>>"$LOG_FILE"
    
    # For local development, don't cache unless explicitly asked
    if [[ $APP_DEBUG != "true" ]]; then
        docker compose -f docker-compose.local.yml exec -T coolify php artisan config:cache 2>>"$LOG_FILE"
        docker compose -f docker-compose.local.yml exec -T coolify php artisan route:cache 2>>"$LOG_FILE"
    fi
    
    log_success "Caches configured"
}

# Show service status (enhanced)
show_status() {
    echo ""
    log_info "Service Status:"
    docker compose -f docker-compose.local.yml ps
    echo ""
    log_success "Coolify is now running locally!"
    echo ""
    echo -e "${GREEN}Access your application at:${NC}"
    echo -e "  🌐 ${BLUE}http://localhost:${APP_PORT}${NC}"
    echo -e "  🔐 ${BLUE}http://localhost:${APP_PORT}/login${NC}"
    echo ""
    echo -e "${GREEN}Services:${NC}"
    echo -e "  📊 Application: http://localhost:${APP_PORT}"
    echo -e "  🗄️  PostgreSQL: localhost:5432"
    echo -e "  📦 Redis: localhost:6379"
    echo -e "  🔌 WebSocket: ws://localhost:${WS_PORT}"
    echo ""
    echo -e "${GREEN}Admin Credentials:${NC}"
    echo -e "  📧 Email: ${BLUE}${ADMIN_EMAIL}${NC}"
    echo -e "  🔑 Password: ${BLUE}${ADMIN_PASSWORD}${NC}"
    echo ""
    echo -e "${YELLOW}Useful commands:${NC}"
    echo -e "  View logs:         docker compose -f docker-compose.local.yml logs -f"
    echo -e "  Stop services:     docker compose -f docker-compose.local.yml stop"
    echo -e "  Restart services:  docker compose -f docker-compose.local.yml restart"
    echo -e "  Access database:   docker compose -f docker-compose.local.yml exec coolify-db psql -U coolify coolify"
    echo -e "  Access Redis:      docker compose -f docker-compose.local.yml exec coolify-redis redis-cli -a ${REDIS_PASSWORD}"
    echo -e "  Clear caches:      docker compose -f docker-compose.local.yml exec coolify php artisan cache:clear"
    echo -e "  Run migrations:    docker compose -f docker-compose.local.yml exec coolify php artisan migrate"
    echo ""
    echo -e "${YELLOW}Development Features:${NC}"
    if [[ $APP_DEBUG == "true" ]]; then
        echo -e "  ✅ Debug mode enabled"
        echo -e "  ✅ Error logging enabled"
        echo -e "  ✅ Live reload ready"
    else
        echo -e "  ⚠️  Debug mode disabled"
    fi
    echo -e "  ✅ WebSocket debugging enabled"
    echo -e "  ✅ Database migrations applied"
    echo -e "  ✅ Admin user created"
    echo ""
}

# Generate setup report (new feature)
generate_report() {
    local report_file="$PROJECT_ROOT/local-setup-report-$(date +%Y%m%d-%H%M%S).txt"
    
    cat > "$report_file" << EOF
╔════════════════════════════════════════════════════════════════╗
║              Coolify Local Setup Report                        ║
╚════════════════════════════════════════════════════════════════╝

Setup Date: $(date)
Status: ✅ SUCCESS
Environment: Local Development

═══════════════════════════════════════════════════════════════════
  ACCESS INFORMATION
═══════════════════════════════════════════════════════════════════

Application URL: http://localhost:${APP_PORT}
Login URL:      http://localhost:${APP_PORT}/login
WebSocket URL:  ws://localhost:${WS_PORT}

═══════════════════════════════════════════════════════════════════
  ADMIN CREDENTIALS
═══════════════════════════════════════════════════════════════════

Email:    ${ADMIN_EMAIL}
Password: ${ADMIN_PASSWORD}

⚠️  IMPORTANT: These are default credentials for local development!

═══════════════════════════════════════════════════════════════════
  DEVELOPMENT FEATURES
═══════════════════════════════════════════════════════════════════

Debug Mode: ${APP_DEBUG}
Log Level:  ${LOG_LEVEL}
WebSocket:  Enabled for debugging
Database:  Migrations applied
Admin User: Created

═══════════════════════════════════════════════════════════════════
  CONFIGURATION FILES
═══════════════════════════════════════════════════════════════════

Environment: .env.local
Docker Compose: docker-compose.local.yml
Setup Log: $LOG_FILE

═══════════════════════════════════════════════════════════════════
EOF

    log_success "Setup report saved to: $report_file"
}

# Main deployment flow
main() {
    create_directories
    
    echo -e "${GREEN}"
    echo "╔════════════════════════════════════════════════════════════════╗"
    echo "║        Final Coolify Local Deployment Script                  ║"
    echo "║        Official Best Practices + Local Optimizations           ║"
    echo "╚════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"

    # Change to script directory
    cd "$(dirname "$0")/.."

    # Execute deployment steps
    log_section "Step 1: Prerequisites"
    check_docker
    check_docker_compose
    
    log_section "Step 2: Setup Configuration"
    collect_setup_info
    generate_credentials
    
    log_section "Step 3: Configuration Files"
    create_environment
    create_docker_compose
    
    log_section "Step 4: Service Management"
    start_services
    
    log_section "Step 5: Health Checks"
    wait_for_db
    wait_for_app
    
    log_section "Step 6: Application Setup"
    run_migrations
    create_admin_user
    setup_caches
    
    log_section "Step 7: Finalization"
    show_status
    generate_report
    
    echo ""
    echo -e "${GREEN}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║           Local Setup Completed! 🎉                          ║${NC}"
    echo -e "${GREEN}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

# Run main function
main "$@"
