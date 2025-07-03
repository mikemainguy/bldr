#!/bin/bash

# Robustly resolve the directory of the actual script, even if called via symlink
SOURCE="${BASH_SOURCE[0]}"
while [ -h "$SOURCE" ]; do
  DIR="$( cd -P "$( dirname "$SOURCE" )" >/dev/null 2>&1 && pwd )"
  SOURCE="$(readlink "$SOURCE")"
  [[ $SOURCE != /* ]] && SOURCE="$DIR/$SOURCE"
done
SCRIPT_DIR="$( cd -P "$( dirname "$SOURCE" )" >/dev/null 2>&1 && pwd )"
source "$SCRIPT_DIR/logging.sh"

# GitHub Actions Runner Start Script
# This script starts the GitHub Actions runner and all associated services

set -e

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
    setup_backup_schedule
    check_service_status
    display_startup_info
}

# Run main function
main "$@" 