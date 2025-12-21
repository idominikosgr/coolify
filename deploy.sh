#!/usr/bin/env bash

# Coolify Quick Start Script
# Detects environment and runs appropriate deployment

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${GREEN}"
echo "╔════════════════════════════════════════╗"
echo "║      Coolify Quick Start Script       ║"
echo "╚════════════════════════════════════════╝"
echo -e "${NC}"

# Change to script directory
cd "$(dirname "$0")"

# Check if .env exists
if [ ! -f .env ]; then
    echo -e "${YELLOW}No .env file found${NC}"
    echo ""
    echo "Please choose your deployment environment:"
    echo "  1) Local Development"
    echo "  2) Production"
    read -p "Enter choice (1 or 2): " -n 1 -r
    echo ""

    case $REPLY in
        1)
            echo -e "${BLUE}Setting up local environment...${NC}"
            cp .env.example .env
            sed -i.bak 's/DB_CONNECTION=sqlite/DB_CONNECTION=pgsql/' .env
            sed -i.bak 's/# DB_HOST=127.0.0.1/DB_HOST=coolify-db/' .env
            sed -i.bak 's/# DB_DATABASE=laravel/DB_DATABASE=coolify/' .env
            sed -i.bak 's/# DB_USERNAME=root/DB_USERNAME=coolify/' .env
            sed -i.bak 's/# DB_PASSWORD=/DB_PASSWORD=coolify_secret/' .env
            sed -i.bak 's/REDIS_HOST=127.0.0.1/REDIS_HOST=coolify-redis/' .env
            sed -i.bak 's/REDIS_PASSWORD=null/REDIS_PASSWORD=redis_secret/' .env
            sed -i.bak 's/APP_URL=http:\/\/localhost/APP_URL=http:\/\/localhost:8000/' .env
            rm -f .env.bak
            ;;
        2)
            echo -e "${BLUE}Setting up production environment...${NC}"
            cp .env.production.example .env
            echo ""
            echo -e "${YELLOW}⚠️  Please edit .env and set the following:${NC}"
            echo "  - APP_URL (your domain)"
            echo "  - APP_KEY (will be generated if empty)"
            echo "  - DB_PASSWORD (strong password)"
            echo "  - REDIS_PASSWORD (strong password)"
            echo ""
            read -p "Press Enter after editing .env file..."
            ;;
        *)
            echo "Invalid choice"
            exit 1
            ;;
    esac
fi

# Detect environment from .env
if grep -q "APP_ENV=production" .env; then
    echo -e "${BLUE}Detected production environment${NC}"
    ./scripts/deploy-prod.sh
else
    echo -e "${BLUE}Detected local/development environment${NC}"
    ./scripts/deploy-local.sh
fi
