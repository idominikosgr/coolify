# Coolify DevOps Guide

This guide provides comprehensive instructions for setting up and managing Coolify in both local development and Azure production environments with full automation.

## 📋 Table of Contents

1. [Quick Start](#quick-start)
2. [Local Development Setup](#local-development-setup)
3. [Azure Production Setup](#azure-production-setup)
4. [Automation & CI/CD](#automation--cicd)
5. [Monitoring & Maintenance](#monitoring--maintenance)
6. [Troubleshooting](#troubleshooting)
7. [Security Best Practices](#security-best-practices)

## 🚀 Quick Start

### Local Development (5 minutes)
```bash
# Clone and setup
git clone <your-coolify-fork>
cd coolify
./scripts/setup-local.sh

# Access Coolify
open http://localhost:8000
```

### Azure Production (15 minutes)
```bash
# Deploy to Azure
./scripts/deploy-azure-enhanced.sh

# Or use GitHub Actions (push to main)
git push origin main
```

## 🏠 Local Development Setup

### Prerequisites
- Docker & Docker Compose
- Git
- OpenSSL (for SSL certificates)

### Automated Setup
```bash
./scripts/setup-local.sh
```

This script:
- ✅ Generates secure credentials
- ✅ Creates `.env.local` configuration
- ✅ Sets up SSL certificates for HTTPS
- ✅ Builds and starts all services
- ✅ Runs database migrations
- ✅ Creates admin user
- ✅ Saves credentials to file

### Manual Setup
```bash
# 1. Create environment file
cp .env.local.example .env.local
# Edit .env.local with your settings

# 2. Start services
docker compose -f docker-compose.local.yml up -d

# 3. Run migrations
docker exec coolify-app-local php artisan migrate

# 4. Create admin user
docker exec coolify-app-local php artisan tinker
# Then run: User::create(['name' => 'Admin', 'email' => 'admin@coolify.local', 'password' => Hash::make('password')])
```

### Local Services
- **Coolify App**: http://localhost:8000
- **Database**: localhost:5432
- **Redis**: localhost:6379
- **WebSocket**: localhost:6001
- **Nginx (HTTPS)**: https://localhost:8443

### Development Features
- **Live Code Mounting**: Changes in `./app`, `./config`, etc. are reflected immediately
- **Debug Mode**: Full debugging enabled
- **Queue Worker**: Background job processing
- **SSL Support**: Self-signed certificates for HTTPS testing

## ☁️ Azure Production Setup

### Prerequisites
- Azure Account with subscription
- Azure CLI installed and configured
- SSH key pair

### One-Click Deployment
```bash
./scripts/deploy-azure-enhanced.sh
```

This script handles:
- ✅ Azure infrastructure provisioning (VM, networking, security)
- ✅ Docker installation on VM
- ✅ Coolify deployment with production configuration
- ✅ Database setup and migrations
- ✅ SSL-ready configuration
- ✅ Health checks and validation
- ✅ Credential management

### Deployment Options

#### Option 1: Enhanced Script (Recommended)
```bash
./scripts/deploy-azure-enhanced.sh
```

#### Option 2: Original Script
```bash
./deploy-azure-software.sh
```

#### Option 3: GitHub Actions
Push to `main` branch to trigger automatic deployment.

### Azure Architecture
```
Azure Resource Group: coolify-rg
├── Virtual Machine: coolify-vm (Ubuntu 24.04 LTS)
├── Network Security Group: coolify-nsg
├── Public IP: Static IP
├── Storage: Premium SSD (50GB+)
└── Docker Services:
    ├── Coolify App (Port 80/443)
    ├── PostgreSQL Database
    ├── Redis Cache
    └── Soketi WebSocket Server
```

### Accessing Azure Deployment
- **Application**: http://<VM-PUBLIC-IP>
- **SSH**: ssh azureuser@<VM-PUBLIC-IP>
- **Management**: All commands saved in deployment report

## 🔄 Automation & CI/CD

### GitHub Actions
Automatic deployment on:
- Push to `main` branch
- New tags (`v*`)
- Manual workflow dispatch

### Auto-Update Script
```bash
# Setup automatic updates
./scripts/auto-update.sh setup

# Check status
./scripts/auto-update.sh status

# Run manual update
./scripts/auto-update.sh run

# Remove auto-update
./scripts/auto-update.sh remove
```

### Update Commands
```bash
# Update existing deployment
./scripts/update-azure.sh

# Force update with latest changes
./scripts/deploy-azure-enhanced.sh update
```

### Cron-Based Updates
The auto-update script can be configured to:
- Check for repository changes hourly/daily/weekly
- Automatically deploy updates
- Send notifications on success/failure
- Maintain update logs

## 📊 Monitoring & Maintenance

### Health Checks
```bash
# Local
docker compose -f docker-compose.local.yml ps

# Azure
ssh azureuser@<VM_IP> "cd ~/coolify && docker compose ps"
```

### Logs
```bash
# Local - All services
docker compose -f docker-compose.local.yml logs -f

# Local - Specific service
docker compose -f docker-compose.local.yml logs -f coolify

# Azure
ssh azureuser@<VM_IP> "cd ~/coolify && docker compose logs -f"
```

### Backups
```bash
# Azure - Manual backup
ssh azureuser@<VM_IP> "cd ~/coolify && ./backup.sh"

# Azure - Automated backup (setup in deployment)
crontab -l
# 0 2 * * * ~/coolify/backup.sh >> ~/backup.log 2>&1
```

### Performance Monitoring
```bash
# Container stats
docker stats

# Resource usage
docker system df

# Azure VM metrics
az monitor metrics list --resource <VM-ID>
```

## 🔧 Troubleshooting

### Common Issues

#### Services Won't Start
```bash
# Check logs
docker compose logs

# Check disk space
df -h

# Restart services
docker compose restart
```

#### Database Connection Issues
```bash
# Check database health
docker exec coolify-db pg_isready -U coolify

# Test connection
docker exec coolify-db psql -U coolify -d coolify -c "SELECT version();"
```

#### Application Not Responding
```bash
# Check application logs
docker compose logs coolify

# Verify port accessibility
curl -I http://localhost:8000

# Check Azure NSG rules (Azure only)
az network nsg rule list --resource-group coolify-rg --nsg-name coolify-nsg
```

### Recovery Procedures

#### Restore from Backup
```bash
# Azure - Database restore
ssh azureuser@<VM_IP> "cd ~/coolify && gunzip -c backup-YYYYMMDD.sql.gz | docker exec -i coolify-db psql -U coolify coolify"

# Restart services
ssh azureuser@<VM_IP> "cd ~/coolify && docker compose restart"
```

#### Reset Local Environment
```bash
# Stop and remove all containers
docker compose -f docker-compose.local.yml down -v

# Remove all images
docker system prune -a

# Rebuild from scratch
./scripts/setup-local.sh
```

## 🔒 Security Best Practices

### Local Development
- Use strong, unique passwords
- Don't expose ports to public internet
- Keep Docker and dependencies updated
- Use HTTPS for local testing

### Azure Production
- Restrict SSH access to your IP only
- Use strong passwords and keys
- Enable SSL/TLS certificates
- Configure regular backups
- Monitor with Azure Security Center
- Use Network Security Groups properly
- Enable Azure Disk Encryption

### Credential Management
- Never commit `.env` files to git
- Use Azure Key Store for production secrets
- Rotate passwords regularly
- Store deployment reports securely

### Network Security
```bash
# Azure - Restrict SSH to your IP
az network nsg rule update \
  --resource-group coolify-rg \
  --nsg-name coolify-nsg \
  --name SSH \
  --source-address-prefix <YOUR-IP>

# Local - Firewall rules
sudo ufw allow 22/tcp
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw enable
```

## 📁 File Structure

```
coolify/
├── scripts/
│   ├── setup-local.sh              # Local development setup
│   ├── deploy-azure-enhanced.sh    # Azure deployment
│   ├── update-azure.sh             # Azure updates
│   └── auto-update.sh              # Repository monitoring
├── docker/
│   └── nginx/
│       └── local.conf              # Nginx configuration
├── docker-compose.local.yml        # Local development
├── docker-compose.prod.yml         # Azure production
├── .env.local                      # Local environment
├── azure-config.json               # Azure deployment config
├── azure-state.json                # Deployment state
├── .github/workflows/
│   └── azure-deploy.yml            # GitHub Actions
└── logs/
    └── update.log                  # Auto-update logs
```

## 🎯 Next Steps

1. **Local Development**: Run `./scripts/setup-local.sh` to start experimenting
2. **Azure Deployment**: Run `./scripts/deploy-azure-enhanced.sh` for production
3. **Automation**: Set up `./scripts/auto-update.sh setup` for hands-off updates
4. **Monitoring**: Configure alerts and monitoring
5. **Customization**: Modify configurations for your specific needs

## 📞 Support

- **Documentation**: Check this guide and inline comments
- **Issues**: Report problems in the repository
- **Community**: Join the Coolify Discord
- **Azure**: Use Azure support for infrastructure issues

---

**Note**: This setup provides a complete development-to-production pipeline with full automation. Adjust configurations based on your specific requirements and security policies.
