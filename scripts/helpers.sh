#!/usr/bin/env bash

# Coolify Helper Scripts
# Collection of utility scripts for managing Coolify

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

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

# Change to project directory
cd "$(dirname "$0")/.."

# Show help
show_help() {
    echo -e "${GREEN}Coolify Helper Commands${NC}"
    echo ""
    echo "Usage: ./scripts/helpers.sh <command>"
    echo ""
    echo "Commands:"
    echo "  logs         - Show application logs"
    echo "  shell        - Open shell in application container"
    echo "  db-shell     - Open PostgreSQL shell"
    echo "  redis-cli    - Open Redis CLI"
    echo "  restart      - Restart all services"
    echo "  stop         - Stop all services"
    echo "  start        - Start all services"
    echo "  status       - Show service status"
    echo "  clean        - Clean up Docker resources"
    echo "  backup-db    - Create database backup"
    echo "  restore-db   - Restore database from backup"
    echo "  artisan      - Run artisan command (pass command as arguments)"
    echo "  fresh        - Fresh install (WARNING: deletes all data)"
    echo ""
}

# View logs
view_logs() {
    log_info "Showing application logs (Ctrl+C to exit)..."
    docker compose logs -f coolify
}

# Open shell
open_shell() {
    log_info "Opening shell in application container..."
    docker compose exec coolify bash
}

# Open database shell
open_db_shell() {
    log_info "Opening PostgreSQL shell..."
    docker compose exec coolify-db psql -U coolify -d coolify
}

# Open Redis CLI
open_redis_cli() {
    log_info "Opening Redis CLI..."
    redis_password=$(grep "^REDIS_PASSWORD=" .env | cut -d'=' -f2)
    docker compose exec coolify-redis redis-cli -a "$redis_password"
}

# Restart services
restart_services() {
    log_info "Restarting services..."
    docker compose restart
    log_success "Services restarted"
}

# Stop services
stop_services() {
    log_info "Stopping services..."
    docker compose stop
    log_success "Services stopped"
}

# Start services
start_services() {
    log_info "Starting services..."
    docker compose start
    log_success "Services started"
}

# Show status
show_status() {
    log_info "Service Status:"
    docker compose ps
}

# Clean up Docker resources
clean_docker() {
    log_warning "This will remove stopped containers, unused networks, and dangling images"
    read -p "Continue? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_info "Cancelled"
        return
    fi

    log_info "Cleaning up Docker resources..."
    docker compose down --remove-orphans
    docker system prune -f
    log_success "Cleanup complete"
}

# Backup database
backup_db() {
    log_info "Creating database backup..."

    timestamp=$(date +%Y%m%d_%H%M%S)
    backup_dir="backups"
    mkdir -p "$backup_dir"

    docker compose exec -T coolify-db pg_dump -U coolify coolify | gzip > "${backup_dir}/coolify_backup_${timestamp}.sql.gz"
    log_success "Database backed up to ${backup_dir}/coolify_backup_${timestamp}.sql.gz"
}

# Restore database
restore_db() {
    if [ -z "$1" ]; then
        log_error "Please provide backup file path"
        echo "Usage: ./scripts/helpers.sh restore-db <backup-file>"
        ls -lh backups/*.sql.gz 2>/dev/null || log_info "No backups found"
        return 1
    fi

    if [ ! -f "$1" ]; then
        log_error "Backup file not found: $1"
        return 1
    fi

    log_warning "This will restore database from backup: $1"
    log_warning "ALL CURRENT DATA WILL BE LOST!"
    read -p "Continue? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_info "Cancelled"
        return
    fi

    log_info "Restoring database..."
    gunzip < "$1" | docker compose exec -T coolify-db psql -U coolify -d coolify
    log_success "Database restored from $1"
}

# Run artisan command
run_artisan() {
    if [ -z "$1" ]; then
        log_error "Please provide artisan command"
        echo "Usage: ./scripts/helpers.sh artisan <command>"
        return 1
    fi

    log_info "Running artisan command: $*"
    docker compose exec coolify php artisan "$@"
}

# Fresh install
fresh_install() {
    log_warning "This will DELETE ALL DATA and perform a fresh installation!"
    log_warning "This action CANNOT be undone!"
    read -p "Are you absolutely sure? (type 'yes' to continue): " -r
    echo
    if [[ ! $REPLY == "yes" ]]; then
        log_info "Cancelled"
        return
    fi

    log_info "Performing fresh installation..."
    docker compose down -v
    docker compose up -d

    log_info "Waiting for services to be ready..."
    sleep 10

    docker compose exec coolify php artisan migrate:fresh --force
    log_success "Fresh installation complete"
}

# Main command router
case "${1:-help}" in
    logs)
        view_logs
        ;;
    shell)
        open_shell
        ;;
    db-shell)
        open_db_shell
        ;;
    redis-cli)
        open_redis_cli
        ;;
    restart)
        restart_services
        ;;
    stop)
        stop_services
        ;;
    start)
        start_services
        ;;
    status)
        show_status
        ;;
    clean)
        clean_docker
        ;;
    backup-db)
        backup_db
        ;;
    restore-db)
        restore_db "$2"
        ;;
    artisan)
        shift
        run_artisan "$@"
        ;;
    fresh)
        fresh_install
        ;;
    help|*)
        show_help
        ;;
esac
