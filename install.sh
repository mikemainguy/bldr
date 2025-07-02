#!/bin/bash

# GitHub Actions Runner Universal Installer
#
# Usage (Linux/macOS):
#   curl -sSL https://raw.githubusercontent.com/mikemainguy/bldr/main/install.sh | bash
#
# Usage (Windows GitBash):
#   curl -sSL https://raw.githubusercontent.com/mikemainguy/bldr/main/install.sh | bash
#
# This script will set up the bldr repo for you in ~/.bldr (or a custom directory).
#
# For PowerShell on Windows, use the install.ps1 script instead.

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
║    Ubuntu Linux, macOS, and GitBash (Windows)                ║
║                                                              ║
║    This script will set up a complete GitHub Actions        ║
║    self-hosted runner with monitoring and deployment        ║
║    capabilities for Node.js applications.                   ║
║                                                              ║
╚══════════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
}

# OS detection
check_os() {
    case "$(uname -s)" in
        Linux*)   export OS=Linux;;
        Darwin*)  export OS=Mac;;
        MINGW*|MSYS*|CYGWIN*) export OS=WindowsGitBash;;
        *)        export OS="UNKNOWN";;
    esac

    if [[ "$OS" == "Linux" ]]; then
        log "Detected Linux environment."
    elif [[ "$OS" == "Mac" ]]; then
        log "Detected macOS environment."
    elif [[ "$OS" == "WindowsGitBash" ]]; then
        log "Detected Windows (GitBash) environment."
        warn "For PowerShell, use install.ps1 instead."
    else
        error "Unsupported OS: $(uname -s). This script supports Linux, macOS, and GitBash."
    fi
}

# Check prerequisites
check_prerequisites() {
    log "Checking prerequisites..."
    if ! command -v curl &> /dev/null; then
        warn "curl not found. Attempting to install curl..."
        install_curl
    fi
    if ! command -v git &> /dev/null; then
        warn "git not found. Attempting to install git..."
        install_git
    fi
    if ! command -v unzip &> /dev/null; then
        warn "unzip not found. If git clone fails, zip fallback may not work."
    fi
    log "Prerequisites check passed."
}

# Install curl based on OS
install_curl() {
    log "Installing curl for OS: $OS"
    if [[ "$OS" == "Linux" ]]; then
        # Detect Linux distribution
        if command -v apt-get &> /dev/null; then
            log "Installing curl using apt-get..."
            sudo apt-get update && sudo apt-get install -y curl
        elif command -v yum &> /dev/null; then
            log "Installing curl using yum..."
            sudo yum install -y curl
        elif command -v dnf &> /dev/null; then
            log "Installing curl using dnf..."
            sudo dnf install -y curl
        elif command -v pacman &> /dev/null; then
            log "Installing curl using pacman..."
            sudo pacman -S --noconfirm curl
        elif command -v zypper &> /dev/null; then
            log "Installing curl using zypper..."
            sudo zypper install -y curl
        else
            error "Could not detect package manager. Please install curl manually."
        fi
    elif [[ "$OS" == "Mac" ]]; then
        log "Installing curl using Homebrew..."
        if command -v brew &> /dev/null; then
            brew install curl
        else
            error "Homebrew not found. Please install Homebrew first or install curl manually."
        fi
    elif [[ "$OS" == "WindowsGitBash" ]]; then
        error "curl not found in GitBash. Please install curl manually or use wget instead."
    else
        error "Could not install curl automatically. Please install curl manually."
    fi
    
    # Verify curl installation
    if command -v curl &> /dev/null; then
        log "curl installed successfully: $(curl --version | head -n1)"
    else
        error "curl installation failed. Please install curl manually."
    fi
}

# Install git based on OS
install_git() {
    log "Installing git for OS: $OS"
    if [[ "$OS" == "Linux" ]]; then
        # Detect Linux distribution
        if command -v apt-get &> /dev/null; then
            log "Installing git using apt-get..."
            sudo apt-get update && sudo apt-get install -y git
        elif command -v yum &> /dev/null; then
            log "Installing git using yum..."
            sudo yum install -y git
        elif command -v dnf &> /dev/null; then
            log "Installing git using dnf..."
            sudo dnf install -y git
        elif command -v pacman &> /dev/null; then
            log "Installing git using pacman..."
            sudo pacman -S --noconfirm git
        elif command -v zypper &> /dev/null; then
            log "Installing git using zypper..."
            sudo zypper install -y git
        else
            error "Could not detect package manager. Please install git manually."
        fi
    elif [[ "$OS" == "Mac" ]]; then
        log "Installing git using Homebrew..."
        if command -v brew &> /dev/null; then
            brew install git
        else
            error "Homebrew not found. Please install Homebrew first or install git manually."
        fi
    elif [[ "$OS" == "WindowsGitBash" ]]; then
        error "Git not found in GitBash. Please install Git for Windows from https://git-scm.com/download/win"
    else
        error "Could not install git automatically. Please install git manually."
    fi
    
    # Verify git installation
    if command -v git &> /dev/null; then
        log "Git installed successfully: $(git --version)"
    else
        error "Git installation failed. Please install git manually."
    fi
}

# Get installation directory
get_install_dir() {
    if [[ -n "$1" ]]; then
        INSTALL_DIR="$1"
    else
        INSTALL_DIR="$HOME/.bldr"
    fi
    mkdir -p "$INSTALL_DIR"
    cd "$INSTALL_DIR"
    log "Installation directory: $INSTALL_DIR"
}

# Download repository
download_repository() {
    log "Downloading GitHub Actions runner setup..."
    REPO_URL="https://github.com/mikemainguy/bldr"
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
    if git clone "$REPO_URL" bldr 2>/dev/null; then
        log "Repository downloaded successfully"
    else
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
GITHUB_TOKEN=your_github_personal_access_token_here
GITHUB_REPOSITORY=owner/repository-name
RUNNER_LABELS=ubuntu,nodejs,self-hosted
RUNNER_NAME=ubuntu-runner-$(hostname)
RUNNER_WORK_DIRECTORY=/home/github-runner/_work
RUNNER_USER=github-runner
RUNNER_GROUP=github-runner
PRODUCTION_HOST=your-production-server.com
PRODUCTION_USER=deploy
PRODUCTION_PORT=22
PRODUCTION_PATH=/var/www/apps
PRODUCTION_BACKUP_PATH=/var/backups
DOMAIN_NAME=your-app-domain.com
SSL_EMAIL=admin@your-domain.com
SSL_STAGING=false
DOCKER_REGISTRY=your-registry.com
DOCKER_USERNAME=your-docker-username
DOCKER_PASSWORD=your-docker-password
DOCKER_IMAGE_PREFIX=your-app
PROMETHEUS_PORT=9090
GRAFANA_PORT=3000
GRAFANA_ADMIN_USER=admin
GRAFANA_ADMIN_PASSWORD=secure_password_here
LOG_LEVEL=info
LOG_RETENTION_DAYS=30
LOG_PATH=/var/log/github-runner
BACKUP_RETENTION_DAYS=7
BACKUP_SCHEDULE="0 2 * * *"
BACKUP_PATH=/var/backups
FIREWALL_ENABLED=true
SSH_KEY_PATH=/home/github-runner/.ssh/id_rsa
SSL_CERT_PATH=/etc/ssl/certs
SSL_KEY_PATH=/etc/ssl/private
RUNNER_MAX_CONCURRENT_JOBS=4
RUNNER_MEMORY_LIMIT=4g
RUNNER_CPU_LIMIT=2
SLACK_WEBHOOK_URL=your_slack_webhook_url
EMAIL_NOTIFICATIONS=false
EMAIL_SMTP_HOST=smtp.gmail.com
EMAIL_SMTP_PORT=587
EMAIL_USER=your-email@gmail.com
EMAIL_PASSWORD=your-app-password
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

# Ask user if they want to configure now
ask_for_configuration() {
    echo ""
    echo -e "${CYAN}⚙️  Configuration Setup${NC}"
    echo "=========================="
    echo ""
    info "Would you like to configure your environment now?"
    echo "  This will guide you through setting up all required variables"
    echo "  including GitHub tokens, server details, and deployment settings."
    echo ""
    
    # Check if we're running in a pipe (curl | bash) or if stdin is not available
    if [[ ! -t 0 ]] || [[ -z "$PS1" ]]; then
        # Running in pipe or non-interactive mode
        echo ""
        warn "⚠️  Interactive input not available (running via curl | bash)"
        echo "   The configuration script will be available for you to run manually."
        echo ""
        show_manual_config_instructions
        return
    fi
    
    read -p "Run interactive configuration now? (Y/n): " run_config
    
    if [[ $run_config =~ ^[Nn]$ ]]; then
        show_manual_config_instructions
    else
        run_configuration_script
    fi
}

# Run the configuration script
run_configuration_script() {
    echo ""
    log "Starting interactive configuration..."
    echo ""
    
    if [[ -f "scripts/configure.sh" ]]; then
        ./scripts/configure.sh
        if [[ $? -eq 0 ]]; then
            show_configuration_complete
        else
            warn "Configuration was interrupted or failed"
            show_manual_config_instructions
        fi
    else
        error "Configuration script not found"
        show_manual_config_instructions
    fi
}

# Show configuration complete message
show_configuration_complete() {
    echo ""
    echo -e "${GREEN}✅ Configuration Complete!${NC}"
    echo ""
    info "Your environment has been configured successfully!"
    echo ""
    show_deployment_instructions
}

# Show manual configuration instructions
show_manual_config_instructions() {
    echo ""
    echo -e "${YELLOW}📝 Configuration Required${NC}"
    echo "============================="
    echo ""
    info "To configure your environment:"
    echo ""
    echo "  🎯 RECOMMENDED: Run the interactive configuration script:"
    echo "     ./scripts/configure.sh"
    echo ""
    echo "  📝 OR manually edit the .env file:"
    echo "     nano .env"
    echo ""
    echo "  The interactive script will guide you through all settings"
    echo "  with validation and helpful tips."
    echo ""
    show_deployment_instructions
}

# Show deployment instructions
show_deployment_instructions() {
    echo -e "${CYAN}"
    cat << 'EOF'
╔══════════════════════════════════════════════════════════════╗
║                                                              ║
║    🚀 Next Steps for Deployment                              ║
║                                                              ║
║    1. Transfer files to your Ubuntu server:                 ║
║       scp -r . user@your-server:/path/to/installation       ║
║                                                              ║
║    2. SSH to your Ubuntu server and run:                    ║
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
    echo ""
    info "Important files:"
    echo "  📄 .env                    - Environment configuration"
    echo "  📄 README.md               - Quick start guide"
    echo "  📄 docs/setup.md           - Detailed setup instructions"
    echo "  📄 IMPLEMENTATION_PLAN.md  - Complete project plan"
    echo "  🔧 scripts/                - Setup and management scripts"
    echo "  📋 workflows/              - GitHub Actions workflow templates"
    echo ""
}

# Show next steps (legacy function - now just calls ask_for_configuration)
show_next_steps() {
    ask_for_configuration
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
    echo "  INSTALL_DIR    Installation directory (default: ~/.bldr)"
    echo ""
    echo "Examples:"
    echo "  $0                           # Install in ~/.bldr"
    echo "  $0 /opt/bldr                 # Install in /opt/bldr"
    echo "  curl -sSL https://raw.githubusercontent.com/mikemainguy/bldr/main/install.sh | bash"
    echo ""
    echo "For more information, visit: https://github.com/mikemainguy/bldr"
}

# Show version
show_version() {
    echo "GitHub Actions Runner Installer v1.0.0"
    echo "Copyright (c) 2024 Michael Mainguy"
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
            -* )
                error "Unknown option: $1"
                ;;
            * )
                INSTALL_DIR="$1"
                shift
                ;;
        esac
    done
}

# Main installation function
main() {
    show_banner
    parse_args "$@"
    check_os
    check_prerequisites
    get_install_dir "$INSTALL_DIR"
    download_repository
    setup_environment
    make_scripts_executable
    show_next_steps
}

trap 'echo -e "\n${RED}Installation interrupted${NC}"; exit 1' INT TERM

main "$@" 