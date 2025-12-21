#!/usr/bin/env bash

# Coolify Production Deployment Script
# This script deploys Coolify in production mode with optimizations

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Helper functions
log_info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

log_success() {
    echo -e "${GREEN}✓${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

log_error() {
    echo -e "${RED}✗${NC} $1"
}

# Check if Docker is installed and running
check_docker() {
    log_info "Checking Docker installation..."
    if ! command -v docker &> /dev/null; then
        log_error "Docker is not installed. Please install Docker first."
        exit 1
    fi

    if ! docker info &> /dev/null; then
        log_error "Docker is not running. Please start Docker."
        exit 1
    fi

    log_success "Docker is installed and running"
}

# Check if Docker Compose is available
check_docker_compose() {
    log_info "Checking Docker Compose..."
    if ! docker compose version &> /dev/null; then
        log_error "Docker Compose is not available. Please install Docker Compose."
        exit 1
    fi
    log_success "Docker Compose is available"
}

# Validate production environment
validate_prod_env() {
    log_info "Validating production environment..."

    if [ ! -f .env ]; then
        log_error ".env file not found. Please create it from .env.production.example"
        exit 1
    fi

    # Check for required production variables
    required_vars=("APP_KEY" "DB_PASSWORD" "REDIS_PASSWORD" "APP_URL")
    missing_vars=()

    for var in "${required_vars[@]}"; do
        if ! grep -q "^${var}=.\+" .env; then
            missing_vars+=("$var")
        fi
    done

    if [ ${#missing_vars[@]} -ne 0 ]; then
        log_error "Missing required environment variables: ${missing_vars[*]}"
        log_info "Please set these in your .env file"
        exit 1
    fi

    # Ensure APP_ENV is production
    if ! grep -q "APP_ENV=production" .env; then
        log_warning "APP_ENV is not set to production. Please update your .env file."
        read -p "Continue anyway? (y/N) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi

    # Ensure APP_DEBUG is false
    if grep -q "APP_DEBUG=true" .env; then
        log_warning "APP_DEBUG is set to true. This should be false in production."
        read -p "Continue anyway? (y/N) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi

    log_success "Production environment validated"
}

# Backup database before deployment
backup_database() {
    if docker compose ps | grep -q "coolify-db.*running"; then
        log_info "Creating database backup..."

        timestamp=$(date +%Y%m%d_%H%M%S)
        backup_dir="backups"
        mkdir -p "$backup_dir"

        docker compose exec -T coolify-db pg_dump -U coolify coolify | gzip > "${backup_dir}/coolify_backup_${timestamp}.sql.gz"
        log_success "Database backed up to ${backup_dir}/coolify_backup_${timestamp}.sql.gz"
    else
        log_info "No running database to backup (first deployment)"
    fi
}

# Pull latest images (if using pre-built images)
pull_images() {
    log_info "Pulling latest images..."
    docker compose pull 2>/dev/null || log_info "No images to pull (using local build)"
}

# Build Docker images with production optimizations
build_images() {
    log_info "Building production Docker images..."
    docker compose build --no-cache --pull
    log_success "Docker images built successfully"
}

# Stop services gracefully
stop_services() {
    if docker compose ps | grep -q "running"; then
        log_info "Stopping existing services gracefully..."
        docker compose stop
        log_success "Services stopped"
    fi
}

# Start services in production mode
start_services() {
    log_info "Starting services in production mode..."
    docker compose up -d --remove-orphans
    log_success "Services started"
}

# Wait for services to be healthy
wait_for_services() {
    log_info "Waiting for services to be healthy..."

    max_attempts=60
    attempt=1

    while [ $attempt -le $max_attempts ]; do
        if docker compose ps | grep -q "coolify-db.*healthy"; then
            log_success "Database is healthy"
            break
        fi

        echo -n "."
        sleep 2
        attempt=$((attempt + 1))

        if [ $attempt -gt $max_attempts ]; then
            log_error "Database failed to become healthy"
            return 1
        fi
    done

    attempt=1
    while [ $attempt -le $max_attempts ]; do
        if docker compose ps | grep -q "coolify.*healthy"; then
            log_success "Application is healthy"
            return 0
        fi

        echo -n "."
        sleep 2
        attempt=$((attempt + 1))

        if [ $attempt -gt $max_attempts ]; then
            log_warning "Application health check timeout"
            return 0
        fi
    done
}

# Run migrations safely
run_migrations() {
    log_info "Running database migrations..."
    docker compose exec -T coolify php artisan migrate --force
    log_success "Migrations completed"
}

# Optimize application
optimize_app() {
    log_info "Optimizing application..."
    docker compose exec -T coolify php artisan config:cache
    docker compose exec -T coolify php artisan route:cache
    docker compose exec -T coolify php artisan view:cache
    log_success "Application optimized"
}

# Show deployment status
show_status() {
    echo ""
    log_info "Deployment Status:"
    docker compose ps
    echo ""
    log_success "Coolify production deployment complete!"
    echo ""

    # Get APP_URL from .env
    app_url=$(grep "^APP_URL=" .env | cut -d'=' -f2)

    echo -e "${GREEN}Access your application at:${NC}"
    echo -e "  🌐 ${BLUE}${app_url}${NC}"
    echo ""
    echo -e "${YELLOW}Production Management:${NC}"
    echo -e "  View logs:         docker compose logs -f coolify"
    echo -e "  Monitor:           docker compose ps"
    echo -e "  Shell access:      docker compose exec coolify bash"
    echo -e "  Backups location:  ./backups/"
    echo ""
    echo -e "${RED}Security Reminders:${NC}"
    echo -e "  ⚠️  Ensure firewall rules are configured"
    echo -e "  ⚠️  Regular backups are scheduled"
    echo -e "  ⚠️  SSL/TLS certificates are configured"
    echo -e "  ⚠️  Monitor logs for security issues"
    echo ""
}

# Main deployment flow
main() {
    echo -e "${GREEN}"
    echo "╔════════════════════════════════════════╗"
    echo "║  Coolify Production Deployment Script ║"
    echo "╚════════════════════════════════════════╝"
    echo -e "${NC}"

    log_warning "This script will deploy Coolify in PRODUCTION mode!"
    read -p "Continue with production deployment? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_info "Deployment cancelled"
        exit 0
    fi

    # Change to script directory
    cd "$(dirname "$0")/.."

    check_docker
    check_docker_compose
    validate_prod_env
    backup_database
    pull_images
    build_images
    stop_services
    start_services
    wait_for_services
    run_migrations
    optimize_app
    show_status
}

# Run main function
main "$@"
