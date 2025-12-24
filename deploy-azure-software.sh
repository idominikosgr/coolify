#!/bin/bash

# Coolify Azure Software Deployment Script (Phase 2)
# This script deploys Coolify software to an already-provisioned Azure VM
# Prerequisites: Azure VM with Ubuntu 22.04/24.04, SSH access configured

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Helper functions
print_info() {
    echo -e "${BLUE}ℹ ${1}${NC}"
}

print_success() {
    echo -e "${GREEN}✓ ${1}${NC}"
}

print_error() {
    echo -e "${RED}✗ ${1}${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ ${1}${NC}"
}

# Banner
echo -e "${BLUE}"
echo "╔════════════════════════════════════════════╗"
echo "║   Coolify Azure Software Deployment       ║"
echo "║   Phase 2: Software Installation          ║"
echo "╚════════════════════════════════════════════╝"
echo -e "${NC}"

# Collect deployment information
print_info "Enter deployment details:"
read -p "Azure VM IP Address: " AZURE_IP
read -p "SSH Username [azureuser]: " SSH_USER
SSH_USER=${SSH_USER:-azureuser}

# Verify SSH connectivity
print_info "Verifying SSH connectivity to ${SSH_USER}@${AZURE_IP}..."
if ssh -o ConnectTimeout=10 -o BatchMode=yes ${SSH_USER}@${AZURE_IP} "echo 'SSH OK'" > /dev/null 2>&1; then
    print_success "SSH connection successful"
else
    print_error "Cannot connect via SSH. Please ensure:"
    print_error "  1. VM is running"
    print_error "  2. SSH key is configured (ssh-copy-id ${SSH_USER}@${AZURE_IP})"
    print_error "  3. Port 22 is allowed in Azure NSG"
    exit 1
fi

# Generate secure credentials
print_info "Generating secure credentials..."
DB_PASSWORD=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-25)
REDIS_PASSWORD=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-25)
APP_KEY="base64:$(openssl rand -base64 32)"
ADMIN_PASSWORD=$(openssl rand -base64 16 | tr -d "=+/" | cut -c1-12)
ADMIN_EMAIL="admin@coolify.io"

print_success "Credentials generated"

# Install Docker on remote VM
print_info "Installing Docker on Azure VM..."
ssh ${SSH_USER}@${AZURE_IP} bash << 'ENDSSH'
set -e

# Update system
echo "Updating system packages..."
sudo apt-get update -qq
sudo apt-get upgrade -y -qq

# Install Docker if not already installed
if ! command -v docker &> /dev/null; then
    echo "Installing Docker..."
    curl -fsSL https://get.docker.com -o get-docker.sh
    sudo sh get-docker.sh
    sudo usermod -aG docker $USER
    rm get-docker.sh
    echo "Docker installed successfully"
else
    echo "Docker already installed"
fi

# Install Docker Compose plugin if not already installed
if ! docker compose version &> /dev/null; then
    echo "Installing Docker Compose..."
    sudo apt-get install -y docker-compose-plugin
    echo "Docker Compose installed successfully"
else
    echo "Docker Compose already installed"
fi

# Create deployment directory
mkdir -p ~/coolify
echo "Deployment directory created"
ENDSSH

print_success "Docker installed on Azure VM"

# Create .env file content
print_info "Creating environment configuration..."
ENV_CONTENT="APP_NAME=Coolify
APP_ENV=production
APP_DEBUG=false
APP_URL=http://${AZURE_IP}
APP_KEY=${APP_KEY}

DB_CONNECTION=pgsql
DB_HOST=coolify-db
DB_PORT=5432
DB_DATABASE=coolify
DB_USERNAME=coolify
DB_PASSWORD=${DB_PASSWORD}

REDIS_HOST=coolify-redis
REDIS_PASSWORD=${REDIS_PASSWORD}
REDIS_PORT=6379

CACHE_STORE=redis
SESSION_DRIVER=redis
QUEUE_CONNECTION=redis
BROADCAST_DRIVER=pusher

PUSHER_APP_ID=coolify
PUSHER_APP_KEY=coolify
PUSHER_APP_SECRET=coolify
PUSHER_HOST=coolify-realtime
PUSHER_PORT=6001
PUSHER_SCHEME=http

LOG_CHANNEL=stack
LOG_LEVEL=info
"

# Transfer files to Azure VM
print_info "Transferring deployment files..."

# Transfer docker-compose.prod.yml
if [ -f "docker-compose.prod.yml" ]; then
    scp docker-compose.prod.yml ${SSH_USER}@${AZURE_IP}:~/coolify/docker-compose.yml
    print_success "docker-compose.yml transferred"
else
    print_error "docker-compose.prod.yml not found in current directory"
    exit 1
fi

# Create .env file on remote VM
echo "$ENV_CONTENT" | ssh ${SSH_USER}@${AZURE_IP} "cat > ~/coolify/.env"
print_success "Environment file created"

# Start services
print_info "Starting Coolify services..."
ssh ${SSH_USER}@${AZURE_IP} bash << ENDSSH
set -e
cd ~/coolify

# Pull Docker images
echo "Pulling Docker images..."
docker compose pull

# Start services in detached mode
echo "Starting services..."
docker compose up -d

# Wait for services to be ready
echo "Waiting for services to start..."
sleep 10

# Check service status
docker compose ps
ENDSSH

print_success "Services started"

# Run database migrations
print_info "Running database migrations..."
ssh ${SSH_USER}@${AZURE_IP} bash << ENDSSH
set -e
cd ~/coolify

# Wait for database to be ready
echo "Waiting for database..."
for i in {1..30}; do
    if docker exec coolify-db pg_isready -U coolify > /dev/null 2>&1; then
        echo "Database is ready"
        break
    fi
    if [ \$i -eq 30 ]; then
        echo "Database failed to start"
        exit 1
    fi
    sleep 2
done

# Run migrations
echo "Running migrations..."
docker exec coolify php /var/www/html/artisan migrate --force

echo "Migrations completed"
ENDSSH

print_success "Database migrations completed"

# Create admin user
print_info "Creating admin user..."
ssh ${SSH_USER}@${AZURE_IP} bash << ENDSSH
set -e
cd ~/coolify

# Create admin user
docker exec coolify php /var/www/html/artisan tinker --execute="
\\\$user = new \\App\\Models\\User();
\\\$user->name = 'Admin';
\\\$user->email = '${ADMIN_EMAIL}';
\\\$user->password = \\Hash::make('${ADMIN_PASSWORD}');
\\\$user->save();

\\\$team = \\App\\Models\\Team::find(0);
if (!\\\$team) {
    \\\$team = new \\App\\Models\\Team();
    \\\$team->id = 0;
    \\\$team->name = 'Root Team';
    \\\$team->save();
}

\\\$settings = \\App\\Models\\InstanceSettings::find(0);
if (!\\\$settings) {
    \\\$settings = new \\App\\Models\\InstanceSettings();
    \\\$settings->id = 0;
    \\\$settings->save();
}

echo 'Admin user created successfully';
"
ENDSSH

print_success "Admin user created"

# Run health checks
print_info "Running health checks..."

# Check services
print_info "Checking service status..."
ssh ${SSH_USER}@${AZURE_IP} "cd ~/coolify && docker compose ps" | grep -q "Up" && print_success "All services running" || print_warning "Some services may not be running"

# Check database connectivity
ssh ${SSH_USER}@${AZURE_IP} "docker exec coolify-db pg_isready -U coolify" > /dev/null 2>&1 && print_success "Database connectivity OK" || print_warning "Database check failed"

# Check Redis connectivity
ssh ${SSH_USER}@${AZURE_IP} "docker exec coolify-redis redis-cli -a ${REDIS_PASSWORD} ping" > /dev/null 2>&1 && print_success "Redis connectivity OK" || print_warning "Redis check failed"

# Check application response
if ssh ${SSH_USER}@${AZURE_IP} "curl -s -o /dev/null -w '%{http_code}' http://localhost:80" | grep -q "200\|302"; then
    print_success "Application responding"
else
    print_warning "Application may not be responding correctly"
fi

# Save credentials to file
CREDENTIALS_FILE="coolify-azure-credentials-$(date +%Y%m%d-%H%M%S).txt"
cat > ${CREDENTIALS_FILE} << EOF
╔════════════════════════════════════════════════════════════════╗
║              Coolify Azure Deployment Credentials              ║
╚════════════════════════════════════════════════════════════════╝

Deployment Date: $(date)

═══════════════════════════════════════════════════════════════════
  ACCESS INFORMATION
═══════════════════════════════════════════════════════════════════

Application URL: http://${AZURE_IP}
SSH Access:      ssh ${SSH_USER}@${AZURE_IP}

═══════════════════════════════════════════════════════════════════
  ADMIN CREDENTIALS
═══════════════════════════════════════════════════════════════════

Email:    ${ADMIN_EMAIL}
Password: ${ADMIN_PASSWORD}

═══════════════════════════════════════════════════════════════════
  DATABASE CREDENTIALS
═══════════════════════════════════════════════════════════════════

Host:     coolify-db (internal)
Port:     5432
Database: coolify
Username: coolify
Password: ${DB_PASSWORD}

═══════════════════════════════════════════════════════════════════
  REDIS CREDENTIALS
═══════════════════════════════════════════════════════════════════

Host:     coolify-redis (internal)
Port:     6379
Password: ${REDIS_PASSWORD}

═══════════════════════════════════════════════════════════════════
  IMPORTANT NOTES
═══════════════════════════════════════════════════════════════════

1. Store this file securely and delete it after saving credentials
2. Change the admin password after first login
3. Configure SSL/TLS for production use
4. Set up backups (see AZURE_DEPLOYMENT.md)
5. Configure monitoring and alerts

═══════════════════════════════════════════════════════════════════
  USEFUL COMMANDS
═══════════════════════════════════════════════════════════════════

Check service status:
  ssh ${SSH_USER}@${AZURE_IP} "cd ~/coolify && docker compose ps"

View logs:
  ssh ${SSH_USER}@${AZURE_IP} "cd ~/coolify && docker compose logs -f"

Restart services:
  ssh ${SSH_USER}@${AZURE_IP} "cd ~/coolify && docker compose restart"

Run migrations:
  ssh ${SSH_USER}@${AZURE_IP} "docker exec coolify php /var/www/html/artisan migrate"

═══════════════════════════════════════════════════════════════════
EOF

print_success "Credentials saved to ${CREDENTIALS_FILE}"

# Final summary
echo ""
echo -e "${GREEN}╔════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║            Deployment Completed Successfully! 🎉               ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════════════════════╝${NC}"
echo ""
print_info "Next Steps:"
echo "  1. Access Coolify at: http://${AZURE_IP}"
echo "  2. Login with credentials saved in: ${CREDENTIALS_FILE}"
echo "  3. Review the deployment: AZURE_DEPLOYMENT.md"
echo "  4. Configure SSL/TLS for production"
echo "  5. Set up backups and monitoring"
echo ""
print_warning "SECURITY: Delete ${CREDENTIALS_FILE} after saving credentials securely!"
echo ""
