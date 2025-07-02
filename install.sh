#!/bin/bash

# GitHub Actions Runner Installer for GitBash
# This script can be installed and run with: curl -sSL https://raw.githubusercontent.com/your-repo/bldr/main/install.sh | bash

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
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

info() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')] INFO: $1${NC}"
}

# Banner
show_banner() {
    echo -e "${CYAN}"
    cat << 'EOF'
╔══════════════════════════════════════════════════════════════╗
║                                                              ║
║    🚀 GitHub Actions Runner Installer                        ║
║    Ubuntu Linux + Node.js Autodeployment                     ║
║                                                              ║
║    This script will set up a complete GitHub Actions        ║
║    self-hosted runner with monitoring and deployment        ║
║    capabilities for Node.js applications.                   ║
║                                                              ║
╚══════════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
}

# Check if running on Windows with GitBash
check_environment() {
    if [[ "$OSTYPE" == "msys" || "$OSTYPE" == "cygwin" ]]; then
        log "Detected Windows environment with GitBash"
    else
        warn "This script is designed for Windows with GitBash"
        warn "For Linux/macOS, please use the setup.sh script directly"
    fi
    
    # Check if we're in a WSL environment
    if grep -q Microsoft /proc/version 2>/dev/null; then
        log "Detected WSL environment"
    fi
}

# Check prerequisites
check_prerequisites() {
    log "Checking prerequisites..."
    
    # Check if curl is available
    if ! command -v curl &> /dev/null; then
        error "curl is required but not installed. Please install curl first."
    fi
    
    # Check if git is available
    if ! command -v git &> /dev/null; then
        error "git is required but not installed. Please install Git for Windows first."
    fi
    
    # Check if wget is available (fallback for curl)
    if ! command -v wget &> /dev/null; then
        warn "wget not found, will use curl for downloads"
    fi
    
    log "Prerequisites check passed"
}

# Get installation directory
get_install_dir() {
    if [[ -n "$1" ]]; then
        INSTALL_DIR="$1"
    else
        INSTALL_DIR="$HOME/github-runner"
    fi
    
    # Create installation directory
    mkdir -p "$INSTALL_DIR"
    cd "$INSTALL_DIR"
    
    log "Installation directory: $INSTALL_DIR"
}

# Download repository
download_repository() {
    log "Downloading GitHub Actions runner setup..."
    
    # Repository URL (update this with your actual repository)
    REPO_URL="https://github.com/your-username/bldr"
    
    # Check if directory already exists
    if [[ -d "bldr" ]]; then
        warn "bldr directory already exists"
        read -p "Do you want to overwrite it? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            rm -rf bldr
        else
            error "Installation cancelled"
        fi
    fi
    
    # Clone repository
    if git clone "$REPO_URL" bldr 2>/dev/null; then
        log "Repository downloaded successfully"
    else
        # Fallback: download as zip
        warn "Git clone failed, trying zip download..."
        if command -v curl &> /dev/null; then
            curl -L "$REPO_URL/archive/main.zip" -o bldr.zip
        elif command -v wget &> /dev/null; then
            wget "$REPO_URL/archive/main.zip" -O bldr.zip
        else
            error "Neither curl nor wget available for download"
        fi
        
        unzip bldr.zip
        mv bldr-main bldr
        rm bldr.zip
        log "Repository downloaded successfully (zip)"
    fi
    
    cd bldr
}

# Setup environment
setup_environment() {
    log "Setting up environment configuration..."
    
    # Copy environment template
    if [[ -f "env.example" ]]; then
        cp env.example .env
        log "Environment template copied to .env"
        info "Please edit .env file with your configuration before continuing"
    else
        warn "env.example not found, creating basic .env file"
        create_basic_env
    fi
}

# Create basic environment file
create_basic_env() {
    cat > .env << 'EOF'
# GitHub Actions Runner Configuration
# Please edit these values with your actual configuration

# GitHub Configuration
GITHUB_TOKEN=your_github_personal_access_token_here
GITHUB_REPOSITORY=owner/repository-name
RUNNER_LABELS=ubuntu,nodejs,self-hosted
RUNNER_NAME=ubuntu-runner-$(hostname)

# Runner Configuration
RUNNER_WORK_DIRECTORY=/home/github-runner/_work
RUNNER_USER=github-runner
RUNNER_GROUP=github-runner

# Production Deployment Configuration
PRODUCTION_HOST=your-production-server.com
PRODUCTION_USER=deploy
PRODUCTION_PORT=22
PRODUCTION_PATH=/var/www/apps
PRODUCTION_BACKUP_PATH=/var/backups

# Domain and SSL Configuration
DOMAIN_NAME=your-app-domain.com
SSL_EMAIL=admin@your-domain.com
SSL_STAGING=false

# Docker Configuration
DOCKER_REGISTRY=your-registry.com
DOCKER_USERNAME=your-docker-username
DOCKER_PASSWORD=your-docker-password
DOCKER_IMAGE_PREFIX=your-app

# Monitoring Configuration
PROMETHEUS_PORT=9090
GRAFANA_PORT=3000
GRAFANA_ADMIN_USER=admin
GRAFANA_ADMIN_PASSWORD=secure_password_here

# Logging Configuration
LOG_LEVEL=info
LOG_RETENTION_DAYS=30
LOG_PATH=/var/log/github-runner

# Backup Configuration
BACKUP_RETENTION_DAYS=7
BACKUP_SCHEDULE="0 2 * * *"
BACKUP_PATH=/var/backups

# Security Configuration
FIREWALL_ENABLED=true
SSH_KEY_PATH=/home/github-runner/.ssh/id_rsa
SSL_CERT_PATH=/etc/ssl/certs
SSL_KEY_PATH=/etc/ssl/private

# Resource Limits
RUNNER_MAX_CONCURRENT_JOBS=4
RUNNER_MEMORY_LIMIT=4g
RUNNER_CPU_LIMIT=2

# Notification Configuration
SLACK_WEBHOOK_URL=your_slack_webhook_url
EMAIL_NOTIFICATIONS=false
EMAIL_SMTP_HOST=smtp.gmail.com
EMAIL_SMTP_PORT=587
EMAIL_USER=your-email@gmail.com
EMAIL_PASSWORD=your-app-password

# Development/Testing Configuration
ENVIRONMENT=production
DEBUG_MODE=false
TEST_MODE=false
EOF
}

# Make scripts executable
make_scripts_executable() {
    log "Making scripts executable..."
    
    if [[ -d "scripts" ]]; then
        chmod +x scripts/*.sh
        log "Scripts made executable"
    else
        warn "Scripts directory not found"
    fi
}

# Show next steps
show_next_steps() {
    echo -e "${CYAN}"
    cat << 'EOF'
╔══════════════════════════════════════════════════════════════╗
║                                                              ║
║    ✅ Installation Complete!                                 ║
║                                                              ║
║    Next Steps:                                               ║
║                                                              ║
║    1. Edit the .env file with your configuration:            ║
║       nano .env                                              ║
║                                                              ║
║    2. Transfer files to your Ubuntu server:                 ║
║       scp -r . user@your-server:/path/to/installation       ║
║                                                              ║
║    3. SSH to your Ubuntu server and run:                    ║
║       cd /path/to/installation                              ║
║       ./scripts/setup.sh                                     ║
║       sudo reboot                                            ║
║       ./scripts/register-runner.sh                          ║
║       ./scripts/start-runner.sh                             ║
║                                                              ║
║    For detailed instructions, see:                           ║
║    - docs/setup.md                                           ║
║    - IMPLEMENTATION_PLAN.md                                  ║
║                                                              ║
╚══════════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
    
    log "Installation completed successfully!"
    log "Installation directory: $INSTALL_DIR/bldr"
    
    # Show important files
    echo ""
    info "Important files:"
    echo "  📄 .env                    - Environment configuration"
    echo "  📄 README.md               - Quick start guide"
    echo "  📄 docs/setup.md           - Detailed setup instructions"
    echo "  📄 IMPLEMENTATION_PLAN.md  - Complete project plan"
    echo "  🔧 scripts/                - Setup and management scripts"
    echo "  📋 workflows/              - GitHub Actions workflow templates"
    
    echo ""
    warn "⚠️  IMPORTANT: Edit .env file with your actual configuration before proceeding!"
}

# Show help
show_help() {
    echo "Usage: $0 [OPTIONS] [INSTALL_DIR]"
    echo ""
    echo "Options:"
    echo "  -h, --help     Show this help message"
    echo "  -v, --version  Show version information"
    echo ""
    echo "Arguments:"
    echo "  INSTALL_DIR    Installation directory (default: ~/github-runner)"
    echo ""
    echo "Examples:"
    echo "  $0                           # Install in ~/github-runner"
    echo "  $0 /opt/github-runner        # Install in /opt/github-runner"
    echo "  curl -sSL https://raw.githubusercontent.com/your-repo/bldr/main/install.sh | bash"
    echo ""
    echo "For more information, visit: https://github.com/your-repo/bldr"
}

# Show version
show_version() {
    echo "GitHub Actions Runner Installer v1.0.0"
    echo "Copyright (c) 2024 Your Organization"
    echo "License: MIT"
}

# Parse command line arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                exit 0
                ;;
            -v|--version)
                show_version
                exit 0
                ;;
            -*)
                error "Unknown option: $1"
                ;;
            *)
                INSTALL_DIR="$1"
                shift
                ;;
        esac
    done
}

# Main installation function
main() {
    show_banner
    
    # Parse arguments
    parse_args "$@"
    
    # Check environment
    check_environment
    
    # Check prerequisites
    check_prerequisites
    
    # Get installation directory
    get_install_dir "$INSTALL_DIR"
    
    # Download repository
    download_repository
    
    # Setup environment
    setup_environment
    
    # Make scripts executable
    make_scripts_executable
    
    # Show next steps
    show_next_steps
}

# Handle script interruption
trap 'echo -e "\n${RED}Installation interrupted${NC}"; exit 1' INT TERM

# Run main function
main "$@" 