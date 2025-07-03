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

# Deploy locally in Docker
deploy_locally() {
    log "Deploying $APP_NAME locally in Docker..."
    # Stop and remove any existing container
    if docker ps -a --format '{{.Names}}' | grep -Eq "^${APP_NAME}$"; then
        log "Stopping and removing existing container: $APP_NAME"
        docker stop "$APP_NAME" || true
        docker rm "$APP_NAME" || true
    fi
    # Run the new container
    docker run -d --name "$APP_NAME" \
        -e NODE_ENV="$ENVIRONMENT" \
        -e PORT=3000 \
        -p 3000:3000 \
        "$IMAGE_NAME"
    log "Container $APP_NAME started."
    sleep 5
    # Health check
    if curl -f http://localhost:3000/health > /dev/null 2>&1; then
        log "Health check passed: http://localhost:3000/health"
    else
        warn "Health check failed: http://localhost:3000/health"
    fi
    log "To view logs: docker logs -f $APP_NAME"
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
    log "Starting local deployment process..."
    load_env
    parse_args "$@"
    run_tests
    build_docker_image
    deploy_locally
    send_notifications
    log "Deployment process completed successfully!"
    log "Application: $APP_NAME"
    log "Environment: $ENVIRONMENT"
    log "Build Tag: $BUILD_TAG"
    log "Local URL: http://localhost:3000"
}

# Run main function
main "$@" 