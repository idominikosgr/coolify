#!/usr/bin/env bash

# Coolify Local Deployment Script
# This script sets up and deploys Coolify locally using Docker

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

# Setup environment file
setup_env() {
    log_info "Setting up environment configuration..."

    if [ ! -f .env ]; then
        log_warning ".env file not found, creating from .env.example"
        cp .env.example .env
        log_success "Created .env file"
    else
        log_success ".env file already exists"
    fi

    # Update .env with Docker-specific settings if needed
    if ! grep -q "DB_HOST=coolify-db" .env; then
        log_info "Updating .env with Docker settings..."
        sed -i.bak 's/DB_HOST=.*/DB_HOST=coolify-db/' .env
        sed -i.bak 's/REDIS_HOST=.*/REDIS_HOST=coolify-redis/' .env
        rm -f .env.bak
        log_success "Updated .env with Docker service names"
    fi
}

# Stop and remove existing containers
cleanup_containers() {
    log_info "Cleaning up existing containers..."
    docker compose down --remove-orphans 2>/dev/null || true
    log_success "Cleaned up existing containers"
}

# Build Docker images
build_images() {
    log_info "Building Docker images (this may take a few minutes)..."
    docker compose build --no-cache
    log_success "Docker images built successfully"
}

# Start services
start_services() {
    log_info "Starting services..."
    docker compose up -d
    log_success "Services started"
}

# Wait for database to be ready
wait_for_db() {
    log_info "Waiting for database to be ready..."

    max_attempts=30
    attempt=1

    while [ $attempt -le $max_attempts ]; do
        if docker compose exec -T coolify-db pg_isready -U coolify -d coolify &> /dev/null; then
            log_success "Database is ready"
            return 0
        fi

        echo -n "."
        sleep 2
        attempt=$((attempt + 1))
    done

    log_error "Database failed to become ready after ${max_attempts} attempts"
    return 1
}

# Run migrations
run_migrations() {
    log_info "Running database migrations..."
    docker compose exec -T coolify php artisan migrate --force
    log_success "Migrations completed"
}

# Show service status
show_status() {
    echo ""
    log_info "Service Status:"
    docker compose ps
    echo ""
    log_success "Coolify is now running!"
    echo ""
    echo -e "${GREEN}Access your application at:${NC}"
    echo -e "  🌐 ${BLUE}http://localhost:8000${NC}"
    echo ""
    echo -e "${GREEN}Services:${NC}"
    echo -e "  📊 Application: http://localhost:8000"
    echo -e "  🗄️  PostgreSQL: localhost:5432"
    echo -e "  📦 Redis: localhost:6379"
    echo ""
    echo -e "${YELLOW}Useful commands:${NC}"
    echo -e "  View logs:         docker compose logs -f"
    echo -e "  Stop services:     docker compose stop"
    echo -e "  Restart services:  docker compose restart"
    echo -e "  Shutdown:          docker compose down"
    echo -e "  Shell access:      docker compose exec coolify bash"
    echo ""
}

# Main deployment flow
main() {
    echo -e "${GREEN}"
    echo "╔════════════════════════════════════════╗"
    echo "║   Coolify Local Deployment Script     ║"
    echo "╚════════════════════════════════════════╝"
    echo -e "${NC}"

    # Change to script directory
    cd "$(dirname "$0")/.."

    check_docker
    check_docker_compose
    setup_env
    cleanup_containers
    build_images
    start_services

    # Wait a bit for services to initialize
    sleep 5

    wait_for_db
    run_migrations
    show_status
}

# Run main function
main "$@"
