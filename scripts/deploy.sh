#!/bin/bash

# Node.js Application Deployment Script
# This script handles automated deployment of Node.js applications

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

# Load environment variables
load_env() {
    if [[ -f .env ]]; then
        source .env
    else
        error ".env file not found"
    fi
}

# Parse command line arguments
parse_args() {
    APP_NAME=""
    BRANCH="main"
    ENVIRONMENT="production"
    BUILD_TAG=""
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            --app)
                APP_NAME="$2"
                shift 2
                ;;
            --branch)
                BRANCH="$2"
                shift 2
                ;;
            --env)
                ENVIRONMENT="$2"
                shift 2
                ;;
            --tag)
                BUILD_TAG="$2"
                shift 2
                ;;
            --help)
                show_help
                exit 0
                ;;
            *)
                error "Unknown option: $1"
                ;;
        esac
    done
    
    if [[ -z "$APP_NAME" ]]; then
        error "Application name is required. Use --app <name>"
    fi
}

# Show help
show_help() {
    echo "Usage: $0 --app <app-name> [options]"
    echo ""
    echo "Options:"
    echo "  --app <name>       Application name (required)"
    echo "  --branch <branch>  Git branch to deploy (default: main)"
    echo "  --env <env>        Environment (default: production)"
    echo "  --tag <tag>        Build tag (default: latest)"
    echo "  --help             Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 --app myapp --branch main"
    echo "  $0 --app myapp --env staging --tag v1.0.0"
}

# Validate deployment environment
validate_environment() {
    log "Validating deployment environment..."
    
    # Check if production host is configured
    if [[ -z "$PRODUCTION_HOST" ]]; then
        error "PRODUCTION_HOST not configured in .env file"
    fi
    
    # Check if production user is configured
    if [[ -z "$PRODUCTION_USER" ]]; then
        error "PRODUCTION_USER not configured in .env file"
    fi
    
    # Test SSH connection
    if ! ssh -o ConnectTimeout=10 -o BatchMode=yes "${PRODUCTION_USER}@${PRODUCTION_HOST}" exit 2>/dev/null; then
        error "Cannot connect to production server via SSH"
    fi
    
    log "Environment validation passed."
}

# Build Docker image
build_docker_image() {
    log "Building Docker image for $APP_NAME..."
    
    # Generate build tag if not provided
    if [[ -z "$BUILD_TAG" ]]; then
        BUILD_TAG="$(date +%Y%m%d-%H%M%S)"
    fi
    
    # Build image name
    IMAGE_NAME="${DOCKER_REGISTRY:-localhost}/${DOCKER_IMAGE_PREFIX:-app}/${APP_NAME}:${BUILD_TAG}"
    
    # Build the Docker image
    docker build \
        --build-arg NODE_ENV=${ENVIRONMENT} \
        --build-arg APP_NAME=${APP_NAME} \
        --tag "${IMAGE_NAME}" \
        --tag "${IMAGE_NAME%:*}:latest" \
        .
    
    log "Docker image built: ${IMAGE_NAME}"
}

# Run tests
run_tests() {
    log "Running tests for $APP_NAME..."
    
    # Run npm tests if package.json exists
    if [[ -f "package.json" ]]; then
        if npm run test; then
            log "Tests passed successfully."
        else
            error "Tests failed. Deployment aborted."
        fi
    else
        warn "No package.json found. Skipping tests."
    fi
}

# Push Docker image
push_docker_image() {
    if [[ -n "$DOCKER_REGISTRY" ]]; then
        log "Pushing Docker image to registry..."
        
        # Login to Docker registry
        if [[ -n "$DOCKER_USERNAME" && -n "$DOCKER_PASSWORD" ]]; then
            echo "$DOCKER_PASSWORD" | docker login "$DOCKER_REGISTRY" -u "$DOCKER_USERNAME" --password-stdin
        fi
        
        # Push image
        docker push "${IMAGE_NAME}"
        docker push "${IMAGE_NAME%:*}:latest"
        
        log "Docker image pushed to registry."
    else
        log "No Docker registry configured. Skipping push."
    fi
}

# Deploy to production
deploy_to_production() {
    log "Deploying $APP_NAME to production..."
    
    # Create deployment script for remote execution
    cat > /tmp/deploy_remote.sh <<EOF
#!/bin/bash
set -e

APP_NAME="$APP_NAME"
IMAGE_NAME="$IMAGE_NAME"
ENVIRONMENT="$ENVIRONMENT"
PRODUCTION_PATH="$PRODUCTION_PATH"

# Create application directory
mkdir -p "\${PRODUCTION_PATH}/\${APP_NAME}"

# Create docker-compose file for the application
cat > "\${PRODUCTION_PATH}/\${APP_NAME}/docker-compose.yml" <<'DOCKER_COMPOSE_EOF'
version: '3.8'

services:
  \${APP_NAME}:
    image: \${IMAGE_NAME}
    container_name: \${APP_NAME}
    restart: unless-stopped
    environment:
      - NODE_ENV=\${ENVIRONMENT}
      - PORT=3000
    ports:
      - "3000:3000"
    volumes:
      - ./logs:/app/logs
    networks:
      - app-network

networks:
  app-network:
    driver: bridge
DOCKER_COMPOSE_EOF

# Stop existing container if running
cd "\${PRODUCTION_PATH}/\${APP_NAME}"
docker-compose down || true

# Pull latest image
docker-compose pull

# Start the application
docker-compose up -d

# Wait for application to be ready
sleep 10

# Health check
if curl -f http://localhost:3000/health > /dev/null 2>&1; then
    echo "Deployment successful"
    exit 0
else
    echo "Health check failed"
    exit 1
fi
EOF
    
    # Copy deployment script to production server
    scp /tmp/deploy_remote.sh "${PRODUCTION_USER}@${PRODUCTION_HOST}:/tmp/"
    
    # Execute deployment on production server
    ssh "${PRODUCTION_USER}@${PRODUCTION_HOST}" "chmod +x /tmp/deploy_remote.sh && /tmp/deploy_remote.sh"
    
    # Clean up
    rm /tmp/deploy_remote.sh
    ssh "${PRODUCTION_USER}@${PRODUCTION_HOST}" "rm /tmp/deploy_remote.sh"
    
    log "Deployment completed successfully."
}

# Setup SSL certificate
setup_ssl() {
    if [[ -n "$DOMAIN_NAME" && "$DOMAIN_NAME" != "your-app-domain.com" ]]; then
        log "Setting up SSL certificate for $DOMAIN_NAME..."
        
        # Create SSL setup script
        cat > /tmp/ssl_setup.sh <<EOF
#!/bin/bash
set -e

DOMAIN_NAME="$DOMAIN_NAME"
SSL_EMAIL="$SSL_EMAIL"

# Install certbot if not installed
if ! command -v certbot &> /dev/null; then
    sudo apt update
    sudo apt install -y certbot python3-certbot-nginx
fi

# Obtain SSL certificate
sudo certbot --nginx -d \${DOMAIN_NAME} --email \${SSL_EMAIL} --agree-tos --non-interactive

# Setup auto-renewal
sudo crontab -l 2>/dev/null | { cat; echo "0 12 * * * /usr/bin/certbot renew --quiet"; } | sudo crontab -
EOF
        
        # Execute SSL setup on production server
        scp /tmp/ssl_setup.sh "${PRODUCTION_USER}@${PRODUCTION_HOST}:/tmp/"
        ssh "${PRODUCTION_USER}@${PRODUCTION_HOST}" "chmod +x /tmp/ssl_setup.sh && /tmp/ssl_setup.sh"
        
        # Clean up
        rm /tmp/ssl_setup.sh
        ssh "${PRODUCTION_USER}@${PRODUCTION_HOST}" "rm /tmp/ssl_setup.sh"
        
        log "SSL certificate setup completed."
    fi
}

# Create backup
create_backup() {
    log "Creating backup of current deployment..."
    
    ssh "${PRODUCTION_USER}@${PRODUCTION_HOST}" <<EOF
        BACKUP_DATE=\$(date +%Y%m%d_%H%M%S)
        BACKUP_DIR="${PRODUCTION_BACKUP_PATH}/${APP_NAME}"
        mkdir -p "\${BACKUP_DIR}"
        
        # Backup current application
        if [[ -d "${PRODUCTION_PATH}/${APP_NAME}" ]]; then
            tar czf "\${BACKUP_DIR}/backup_\${BACKUP_DATE}.tar.gz" -C "${PRODUCTION_PATH}" "${APP_NAME}"
            echo "Backup created: \${BACKUP_DIR}/backup_\${BACKUP_DATE}.tar.gz"
        fi
        
        # Clean up old backups (keep last 5)
        ls -t "\${BACKUP_DIR}"/backup_*.tar.gz | tail -n +6 | xargs -r rm
EOF
    
    log "Backup completed."
}

# Send notifications
send_notifications() {
    log "Sending deployment notifications..."
    
    # Slack notification
    if [[ -n "$SLACK_WEBHOOK_URL" ]]; then
        curl -X POST -H 'Content-type: application/json' \
            --data "{
                \"text\": \"🚀 Deployment completed for \`${APP_NAME}\` to \`${ENVIRONMENT}\` environment\",
                \"attachments\": [{
                    \"fields\": [
                        {\"title\": \"Application\", \"value\": \"${APP_NAME}\", \"short\": true},
                        {\"title\": \"Environment\", \"value\": \"${ENVIRONMENT}\", \"short\": true},
                        {\"title\": \"Build Tag\", \"value\": \"${BUILD_TAG}\", \"short\": true},
                        {\"title\": \"Status\", \"value\": \"✅ Success\", \"short\": true}
                    ]
                }]
            }" \
            "$SLACK_WEBHOOK_URL"
    fi
    
    # Email notification (if configured)
    if [[ "$EMAIL_NOTIFICATIONS" == "true" ]]; then
        # Implementation for email notifications
        log "Email notifications not implemented yet."
    fi
    
    log "Notifications sent."
}

# Main deployment function
main() {
    log "Starting deployment process..."
    
    load_env
    parse_args "$@"
    validate_environment
    create_backup
    run_tests
    build_docker_image
    push_docker_image
    deploy_to_production
    setup_ssl
    send_notifications
    
    log "Deployment process completed successfully!"
    log "Application: $APP_NAME"
    log "Environment: $ENVIRONMENT"
    log "Build Tag: $BUILD_TAG"
    log "Production URL: https://${DOMAIN_NAME:-$PRODUCTION_HOST}"
}

# Run main function
main "$@" 