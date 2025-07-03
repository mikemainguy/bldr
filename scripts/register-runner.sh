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

info "Before registering the runner, ensure you have run 'bldr-setup' to install all dependencies."

# Log all commands and their output to a file in the current working directory
LOGFILE="$(pwd)/register-runner.log"
exec > >(tee -a "$LOGFILE") 2>&1
set -x

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

# Fetch registration token using curl and GITHUB_TOKEN
fetch_registration_token() {
    log "Fetching runner registration token using curl and GITHUB_TOKEN..."
    if [[ -z "$GITHUB_TOKEN" ]]; then
        error "GITHUB_TOKEN is not set. Please create a GitHub Personal Access Token with 'repo' and 'admin:repo_hook' scopes and add it to your .env file."
    fi
    REG_TOKEN=$(curl -s -X POST -H "Authorization: token $GITHUB_TOKEN" \
        -H "Accept: application/vnd.github+json" \
        https://api.github.com/repos/${GITHUB_REPOSITORY}/actions/runners/registration-token | jq -r .token)
    if [[ -z "$REG_TOKEN" || "$REG_TOKEN" == "null" ]]; then
        error "Failed to fetch registration token. Check your GITHUB_TOKEN and repository access."
    fi
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
    # Get latest runner version using GitHub API
    RUNNER_VERSION=$(curl -s https://api.github.com/repos/actions/runner/releases/latest | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
    log "Latest runner version: $RUNNER_VERSION"
    # Construct download URL for Linux x64
    DOWNLOAD_URL="https://github.com/actions/runner/releases/download/${RUNNER_VERSION}/actions-runner-linux-x64-${RUNNER_VERSION}.tar.gz"
    log "Download URL: $DOWNLOAD_URL"
    # Fetch release notes and extract SHA-256 hash
    RELEASE_BODY=$(curl -s "https://api.github.com/repos/actions/runner/releases/tags/${RUNNER_VERSION}" | jq -r .body)
    SHA256_EXPECTED=$(echo "$RELEASE_BODY" | grep -A1 "actions-runner-linux-x64-${RUNNER_VERSION}.tar.gz" | grep -o '[a-f0-9]\{64\}' | head -1)
    if [[ -z "$SHA256_EXPECTED" ]]; then
        error "Could not extract SHA-256 hash for version $RUNNER_VERSION from release notes. Aborting download."
    fi
    log "Expected SHA-256: $SHA256_EXPECTED"
    # Create runner directory
    sudo -u github-runner mkdir -p /home/github-runner/actions-runner
    cd /home/github-runner/actions-runner
    # Download runner
    sudo -u github-runner curl -L -o actions-runner-linux-x64-${RUNNER_VERSION}.tar.gz "$DOWNLOAD_URL"
    # Check if the file is a valid gzip archive
    if ! sudo -u github-runner file actions-runner-linux-x64-${RUNNER_VERSION}.tar.gz | grep -q 'gzip compressed data'; then
        echo "Download failed or file is not a valid archive. Contents:"
        sudo -u github-runner head actions-runner-linux-x64-${RUNNER_VERSION}.tar.gz
        error "Runner download failed."
    fi
    # Validate SHA-256 hash
    SHA256_ACTUAL=$(sha256sum actions-runner-linux-x64-${RUNNER_VERSION}.tar.gz | awk '{print $1}')
    if [[ "$SHA256_ACTUAL" != "$SHA256_EXPECTED" ]]; then
        echo "${RED}ERROR: SHA-256 hash mismatch for downloaded runner!${NC}"
        echo "Expected: $SHA256_EXPECTED"
        echo "Actual:   $SHA256_ACTUAL"
        error "The downloaded runner file is corrupt or has been tampered with. Aborting."
    fi
    log "SHA-256 hash validated successfully."
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