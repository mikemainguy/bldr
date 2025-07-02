#!/bin/bash

# GitHub Actions Runner Start Script
# This script starts the GitHub Actions runner and all associated services

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging function
log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

warn() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] WARNING: $1${NC}"
}

error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ERROR: $1${NC}"
    exit 1
}

# Check if .env file exists
check_env_file() {
    if [[ ! -f .env ]]; then
        error ".env file not found. Please run setup.sh first or copy env.example to .env"
    fi
    
    # Source environment variables
    source .env
}

# Check if Docker is running
check_docker() {
    if ! docker info > /dev/null 2>&1; then
        error "Docker is not running. Please start Docker first."
    fi
    
    log "Docker is running."
}

# Start Docker services
start_docker_services() {
    log "Starting Docker services..."
    
    # Start all services defined in docker-compose.yml
    docker-compose up -d
    
    log "Docker services started successfully."
}

# Start GitHub Actions runner
start_github_runner() {
    log "Starting GitHub Actions runner..."
    
    # Start the runner service
    sudo systemctl start actions.runner.*
    
    # Enable the service to start on boot
    sudo systemctl enable actions.runner.*
    
    log "GitHub Actions runner started successfully."
}

# Check service status
check_service_status() {
    log "Checking service status..."
    
    # Check Docker services
    echo ""
    log "Docker Services Status:"
    docker-compose ps
    
    # Check GitHub runner service
    echo ""
    log "GitHub Runner Service Status:"
    sudo systemctl status actions.runner.* --no-pager -l
    
    # Check if runner is connected
    echo ""
    log "Checking runner connection..."
    if curl -s -H "Authorization: token ${GITHUB_TOKEN}" "https://api.github.com/repos/${GITHUB_REPOSITORY}/actions/runners" | grep -q "${RUNNER_NAME}"; then
        log "Runner is connected and registered with GitHub."
    else
        warn "Runner may not be connected. Please check the logs."
    fi
}

# Setup monitoring
setup_monitoring() {
    log "Setting up monitoring..."
    
    # Create Grafana dashboard configuration
    mkdir -p config/grafana/provisioning/dashboards
    mkdir -p config/grafana/provisioning/datasources
    mkdir -p config/grafana/dashboards
    
    # Create Prometheus datasource
    cat > config/grafana/provisioning/datasources/prometheus.yml <<EOF
apiVersion: 1

datasources:
  - name: Prometheus
    type: prometheus
    access: proxy
    url: http://prometheus:9090
    isDefault: true
EOF
    
    # Create GitHub Runner dashboard
    cat > config/grafana/dashboards/github-runner.json <<EOF
{
  "dashboard": {
    "id": null,
    "title": "GitHub Actions Runner",
    "tags": ["github", "actions", "runner"],
    "timezone": "browser",
    "panels": [
      {
        "id": 1,
        "title": "Runner Status",
        "type": "stat",
        "targets": [
          {
            "expr": "up{job=\"github-runner\"}",
            "legendFormat": "Runner Status"
          }
        ]
      },
      {
        "id": 2,
        "title": "System Resources",
        "type": "graph",
        "targets": [
          {
            "expr": "100 - (avg by (instance) (irate(node_cpu_seconds_total{mode=\"idle\"}[5m])) * 100)",
            "legendFormat": "CPU Usage %"
          },
          {
            "expr": "(1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) * 100",
            "legendFormat": "Memory Usage %"
          }
        ]
      }
    ]
  }
}
EOF
    
    log "Monitoring setup completed."
}

# Setup SSL certificates
setup_ssl() {
    if [[ -n "${DOMAIN_NAME}" && "${DOMAIN_NAME}" != "your-app-domain.com" ]]; then
        log "Setting up SSL certificates for ${DOMAIN_NAME}..."
        
        # Create Nginx configuration for SSL
        cat > config/nginx/conf.d/default.conf <<EOF
server {
    listen 80;
    server_name ${DOMAIN_NAME};
    
    location /.well-known/acme-challenge/ {
        root /var/www/html;
    }
    
    location / {
        return 301 https://\$server_name\$request_uri;
    }
}

server {
    listen 443 ssl http2;
    server_name ${DOMAIN_NAME};
    
    ssl_certificate /etc/ssl/certs/${DOMAIN_NAME}.crt;
    ssl_certificate_key /etc/ssl/private/${DOMAIN_NAME}.key;
    
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-RSA-AES256-GCM-SHA512:DHE-RSA-AES256-GCM-SHA512:ECDHE-RSA-AES256-GCM-SHA384:DHE-RSA-AES256-GCM-SHA384;
    ssl_prefer_server_ciphers off;
    
    location / {
        proxy_pass http://github-runner:8080;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOF
        
        log "SSL configuration created. Run certbot to obtain certificates."
    else
        log "Skipping SSL setup - no domain configured."
    fi
}

# Setup backup schedule
setup_backup_schedule() {
    log "Setting up backup schedule..."
    
    # Create backup script
    cat > scripts/backup.sh <<'EOF'
#!/bin/bash

# Backup script for GitHub Actions runner
set -e

BACKUP_DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_DIR="/backups"
RETENTION_DAYS=${BACKUP_RETENTION_DAYS:-7}

# Create backup directory
mkdir -p "${BACKUP_DIR}"

# Backup PostgreSQL database
if docker ps | grep -q postgres; then
    echo "Backing up PostgreSQL database..."
    docker exec postgres pg_dump -U ${DB_USER} ${DB_NAME} > "${BACKUP_DIR}/postgres_${BACKUP_DATE}.sql"
fi

# Backup Grafana data
if docker ps | grep -q grafana; then
    echo "Backing up Grafana data..."
    docker exec grafana tar czf - /var/lib/grafana > "${BACKUP_DIR}/grafana_${BACKUP_DATE}.tar.gz"
fi

# Backup runner configuration
echo "Backing up runner configuration..."
tar czf "${BACKUP_DIR}/runner_config_${BACKUP_DATE}.tar.gz" \
    /home/github-runner/actions-runner/.env \
    /home/github-runner/actions-runner/.runner \
    /home/github-runner/actions-runner/.credentials

# Clean up old backups
find "${BACKUP_DIR}" -name "*.sql" -mtime +${RETENTION_DAYS} -delete
find "${BACKUP_DIR}" -name "*.tar.gz" -mtime +${RETENTION_DAYS} -delete

echo "Backup completed: ${BACKUP_DATE}"
EOF
    
    chmod +x scripts/backup.sh
    
    log "Backup schedule configured."
}

# Display startup information
display_startup_info() {
    log "GitHub Actions runner startup completed!"
    log ""
    log "Services Status:"
    log "  - GitHub Runner: $(sudo systemctl is-active actions.runner.*)"
    log "  - Docker Services: Running"
    log "  - Monitoring: Available at http://localhost:${GRAFANA_PORT:-3000}"
    log "  - Prometheus: Available at http://localhost:${PROMETHEUS_PORT:-9090}"
    log ""
    log "Useful Commands:"
    log "  - View runner logs: sudo journalctl -u actions.runner.* -f"
    log "  - View Docker logs: docker-compose logs -f"
    log "  - Stop services: docker-compose down"
    log "  - Restart runner: sudo systemctl restart actions.runner.*"
    log ""
    log "Monitoring URLs:"
    log "  - Grafana: http://localhost:${GRAFANA_PORT:-3000} (admin/${GRAFANA_ADMIN_PASSWORD:-admin})"
    log "  - Prometheus: http://localhost:${PROMETHEUS_PORT:-9090}"
    log "  - cAdvisor: http://localhost:8080"
    log "  - Node Exporter: http://localhost:9100"
}

# Main function
main() {
    log "Starting GitHub Actions runner and services..."
    
    check_env_file
    check_docker
    start_docker_services
    start_github_runner
    setup_monitoring
    setup_ssl
    setup_backup_schedule
    check_service_status
    display_startup_info
}

# Run main function
main "$@" 