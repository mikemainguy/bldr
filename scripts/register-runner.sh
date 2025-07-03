#!/bin/bash

# GitHub Actions Runner Registration Script
# This script registers a self-hosted runner with GitHub

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

# Validate required environment variables
validate_env_vars() {
    local required_vars=(
        "GITHUB_REPOSITORY"
        "RUNNER_NAME"
        "RUNNER_LABELS"
        "RUNNER_WORK_DIRECTORY"
    )
    
    for var in "${required_vars[@]}"; do
        if [[ -z "${!var}" ]]; then
            error "Required environment variable $var is not set in .env file"
        fi
    done
    
    log "Environment variables validated successfully."
}

# Fetch registration token using gh CLI
fetch_registration_token() {
    log "Fetching runner registration token using gh CLI..."
    if ! command -v gh &> /dev/null; then
        error "GitHub CLI (gh) is not installed. Please install it and run 'gh auth login' first."
    fi
    REG_TOKEN=$(gh api --method POST -H "Accept: application/vnd.github+json" \
        /repos/${GITHUB_REPOSITORY}/actions/runners/registration-token --jq .token)
    if [[ -z "$REG_TOKEN" ]]; then
        error "Failed to fetch registration token. Ensure you are authenticated with 'gh auth login' and have access to the repository."
    fi
    log "Registration token fetched successfully."
}

# Download runner
download_runner() {
    log "Downloading GitHub Actions runner..."
    
    # Get latest runner version
    RUNNER_VERSION=$(curl -s https://api.github.com/repos/actions/runner/releases/latest | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
    log "Latest runner version: $RUNNER_VERSION"
    
    # Create runner directory
    sudo mkdir -p /home/github-runner/actions-runner
    cd /home/github-runner/actions-runner
    
    # Download runner
    sudo -u github-runner curl -o actions-runner-linux-x64-${RUNNER_VERSION}.tar.gz -L https://github.com/actions/runner/releases/download/${RUNNER_VERSION}/actions-runner-linux-x64-${RUNNER_VERSION}.tar.gz
    
    # Extract runner
    sudo -u github-runner tar xzf ./actions-runner-linux-x64-${RUNNER_VERSION}.tar.gz
    
    # Clean up
    sudo -u github-runner rm actions-runner-linux-x64-${RUNNER_VERSION}.tar.gz
    
    log "Runner downloaded and extracted successfully."
}

# Configure runner
configure_runner() {
    log "Configuring GitHub Actions runner..."
    cd /home/github-runner/actions-runner
    fetch_registration_token
    # Configure the runner
    sudo -u github-runner ./config.sh \
        --url "https://github.com/${GITHUB_REPOSITORY}" \
        --token "$REG_TOKEN" \
        --name "${RUNNER_NAME}" \
        --labels "${RUNNER_LABELS}" \
        --work "${RUNNER_WORK_DIRECTORY}" \
        --replace \
        --unattended
    log "Runner configured successfully."
}

# Install runner service
install_runner_service() {
    log "Installing runner service..."
    
    cd /home/github-runner/actions-runner
    
    # Install the service
    sudo -u github-runner ./svc.sh install
    
    log "Runner service installed successfully."
}

# Setup runner environment
setup_runner_env() {
    log "Setting up runner environment..."
    # Create runner environment file
    sudo tee /home/github-runner/actions-runner/.env > /dev/null <<EOF
# GitHub Actions Runner Environment
GITHUB_REPOSITORY=${GITHUB_REPOSITORY}
RUNNER_NAME=${RUNNER_NAME}
RUNNER_LABELS=${RUNNER_LABELS}
RUNNER_WORK_DIRECTORY=${RUNNER_WORK_DIRECTORY}
PRODUCTION_HOST=${PRODUCTION_HOST}
PRODUCTION_USER=${PRODUCTION_USER}
PRODUCTION_PATH=${PRODUCTION_PATH}
DOMAIN_NAME=${DOMAIN_NAME}
DOCKER_REGISTRY=${DOCKER_REGISTRY}
DOCKER_USERNAME=${DOCKER_USERNAME}
DOCKER_PASSWORD=${DOCKER_PASSWORD}
EOF
    # Set proper permissions
    sudo chown github-runner:github-runner /home/github-runner/actions-runner/.env
    sudo chmod 600 /home/github-runner/actions-runner/.env
    log "Runner environment configured successfully."
}

# Setup runner tools
setup_runner_tools() {
    log "Setting up runner tools..."
    
    cd /home/github-runner/actions-runner
    
    # Install additional tools
    sudo -u github-runner ./bin/installdependencies.sh
    
    log "Runner tools installed successfully."
}

# Test runner connection
test_runner_connection() {
    log "Testing runner connection..."
    if gh api repos/${GITHUB_REPOSITORY} > /dev/null 2>&1; then
        log "Runner connection test successful."
    else
        warn "Runner connection test failed. Please check your gh authentication and repository access."
    fi
}

# Display runner information
display_runner_info() {
    log "Runner registration completed successfully!"
    log ""
    log "Runner Information:"
    log "  Name: ${RUNNER_NAME}"
    log "  Repository: ${GITHUB_REPOSITORY}"
    log "  Labels: ${RUNNER_LABELS}"
    log "  Work Directory: ${RUNNER_WORK_DIRECTORY}"
    log ""
    log "Next steps:"
    log "1. Start the runner: ./scripts/start-runner.sh"
    log "2. Check runner status: sudo systemctl status actions.runner.*"
    log "3. View logs: sudo journalctl -u actions.runner.* -f"
    log ""
    log "To unregister the runner:"
    log "  cd /home/github-runner/actions-runner && sudo -u github-runner ./config.sh remove --unattended"
}

# Main function
main() {
    log "Starting GitHub Actions runner registration..."
    
    check_env_file
    validate_env_vars
    download_runner
    configure_runner
    setup_runner_env
    setup_runner_tools
    install_runner_service
    test_runner_connection
    display_runner_info
}

# Run main function
main "$@" 