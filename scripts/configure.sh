#!/bin/bash

# Always operate from the bldr project root, regardless of where called from
SOURCE="${BASH_SOURCE[0]}"
while [ -h "$SOURCE" ]; do
  DIR="$( cd -P "$( dirname "$SOURCE" )" >/dev/null 2>&1 && pwd )"
  SOURCE="$(readlink "$SOURCE")"
  [[ $SOURCE != /* ]] && SOURCE="$DIR/$SOURCE"
done
SCRIPT_DIR="$( cd -P "$( dirname "$SOURCE" )" >/dev/null 2>&1 && pwd )"
cd "$SCRIPT_DIR/.."

# GitHub Actions Runner Configuration Script
# Interactive setup for environment variables

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Logging functions
error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ERROR: $1${NC}" >&2
}

warn() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] WARN: $1${NC}"
}

info() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')] INFO: $1${NC}"
}

log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] INFO: $1${NC}"
}

# Banner
show_banner() {
    local version=$(get_version)
    echo -e "${CYAN}"
    cat << EOF
╔══════════════════════════════════════════════════════════════╗
║                                                              ║
║    ⚙️  GitHub Actions Runner Configuration v$version         ║
║    Interactive Environment Setup                             ║
║                                                              ║
║    This script will guide you through configuring           ║
║    your GitHub Actions runner environment variables.        ║
║                                                              ║
╚══════════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
}

# Validate GitHub token format
validate_github_token() {
    local token="$1"
    if [[ -z "$token" ]]; then
        return 1
    fi
    # GitHub tokens are typically 40 characters (classic) or start with ghp_ (fine-grained)
    if [[ ${#token} -eq 40 ]] || [[ "$token" =~ ^ghp_[a-zA-Z0-9_]+$ ]]; then
        return 0
    fi
    return 1
}

# Validate repository format
validate_repository() {
    local repo="$1"
    if [[ -z "$repo" ]]; then
        return 1
    fi
    # Format: owner/repository-name
    if [[ "$repo" =~ ^[a-zA-Z0-9_-]+/[a-zA-Z0-9_-]+$ ]]; then
        return 0
    fi
    return 1
}

# Validate email format
validate_email() {
    local email="$1"
    if [[ -z "$email" ]]; then
        return 1
    fi
    # Basic email validation
    if [[ "$email" =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
        return 0
    fi
    return 1
}

# Validate domain format
validate_domain() {
    local domain="$1"
    if [[ -z "$domain" ]]; then
        return 1
    fi
    # Basic domain validation
    if [[ "$domain" =~ ^[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*$ ]]; then
        return 0
    fi
    return 1
}

# Validate port number
validate_port() {
    local port="$1"
    if [[ -z "$port" ]]; then
        return 1
    fi
    if [[ "$port" =~ ^[0-9]+$ ]] && [[ "$port" -ge 1 ]] && [[ "$port" -le 65535 ]]; then
        return 0
    fi
    return 1
}

# Prompt with validation
prompt_with_validation() {
    local prompt_text="$1"
    local var_name="$2"
    local validation_func="$3"
    local default_value="$4"
    local help_text="$5"
    
    while true; do
        if [[ -n "$help_text" ]]; then
            echo -e "${CYAN}💡 $help_text${NC}"
        fi
        
        if [[ -n "$default_value" ]]; then
            read -p "$prompt_text [$default_value]: " input
            if [[ -z "$input" ]]; then
                input="$default_value"
            fi
        else
            read -p "$prompt_text: " input
        fi
        
        if $validation_func "$input"; then
            eval "$var_name=\"$input\""
            break
        else
            error "Invalid input. Please try again."
        fi
    done
}

# Prompt for GitHub configuration
configure_github() {
    echo -e "${CYAN}🔧 GitHub Configuration${NC}"
    echo "=================================="
    
    # Offer automatic token generation
    echo ""
    info "GitHub Personal Access Token is required for the runner to authenticate."
    echo ""
    read -p "Would you like to generate a token automatically? (Y/n): " auto_token
    
    if [[ ! $auto_token =~ ^[Nn]$ ]]; then
        # Try automatic token generation
        log "Attempting automatic token generation..."
        echo ""
        
        if [[ -f "scripts/github-token.sh" ]]; then
            generated_token=$(./scripts/github-token.sh --name "bldr-runner-$(hostname)" --scopes "repo,admin:org,workflow" --expiry "90d" | grep -Eo 'ghp_[A-Za-z0-9_]+' || grep -Eo '([a-f0-9]{40})')
            if [[ $? -eq 0 ]] && [[ -n "$generated_token" ]]; then
                GITHUB_TOKEN="$generated_token"
                echo -e "${GREEN}✅ Token generated automatically!${NC}"
                echo -e "${YELLOW}Token starts with: ${GITHUB_TOKEN:0:6}...${NC}"
                log "✅ Token generated automatically"
            else
                echo -e "${RED}❌ Token generation failed. Please enter manually.${NC}"
                warn "Automatic token generation failed, please enter manually"
                prompt_with_validation \
                    "Enter your GitHub Personal Access Token" \
                    "GITHUB_TOKEN" \
                    "validate_github_token" \
                    "" \
                    "Create a token at https://github.com/settings/tokens with 'repo' and 'admin:org' scopes"
            fi
        else
            warn "Token generation script not found, please enter manually"
            prompt_with_validation \
                "Enter your GitHub Personal Access Token" \
                "GITHUB_TOKEN" \
                "validate_github_token" \
                "" \
                "Create a token at https://github.com/settings/tokens with 'repo' and 'admin:org' scopes"
        fi
    else
        prompt_with_validation \
            "Enter your GitHub Personal Access Token" \
            "GITHUB_TOKEN" \
            "validate_github_token" \
            "" \
            "Create a token at https://github.com/settings/tokens with 'repo' and 'admin:org' scopes"
    fi
    
    prompt_with_validation \
        "Enter your GitHub repository (format: owner/repo)" \
        "GITHUB_REPOSITORY" \
        "validate_repository" \
        "" \
        "Example: mikemainguy/my-nodejs-app"
    
    read -p "Enter runner labels (comma-separated) [ubuntu,nodejs,self-hosted]: " RUNNER_LABELS
    RUNNER_LABELS=${RUNNER_LABELS:-ubuntu,nodejs,self-hosted}
    
    read -p "Enter runner name [ubuntu-runner-$(hostname)]: " RUNNER_NAME
    RUNNER_NAME=${RUNNER_NAME:-ubuntu-runner-$(hostname)}
    
    echo ""
}

# Prompt for production server configuration
configure_production() {
    echo -e "${CYAN}🚀 Production Server Configuration${NC}"
    echo "=========================================="
    
    read -p "Enter production server hostname/IP: " PRODUCTION_HOST
    
    read -p "Enter production server username [deploy]: " PRODUCTION_USER
    PRODUCTION_USER=${PRODUCTION_USER:-deploy}
    
    prompt_with_validation \
        "Enter SSH port" \
        "PRODUCTION_PORT" \
        "validate_port" \
        "22" \
        "SSH port for connecting to production server"
    
    read -p "Enter production app path [/var/www/apps]: " PRODUCTION_PATH
    PRODUCTION_PATH=${PRODUCTION_PATH:-/var/www/apps}
    
    read -p "Enter backup path [/var/backups]: " PRODUCTION_BACKUP_PATH
    PRODUCTION_BACKUP_PATH=${PRODUCTION_BACKUP_PATH:-/var/backups}
    
    echo ""
}

# Prompt for domain and SSL configuration
configure_domain() {
    echo -e "${CYAN}🌐 Domain and SSL Configuration${NC}"
    echo "====================================="
    
    prompt_with_validation \
        "Enter your domain name" \
        "DOMAIN_NAME" \
        "validate_domain" \
        "" \
        "Example: myapp.com"
    
    prompt_with_validation \
        "Enter admin email for SSL certificates" \
        "SSL_EMAIL" \
        "validate_email" \
        "" \
        "Used for Let's Encrypt SSL certificate notifications"
    
    read -p "Use staging SSL certificates? (y/N): " ssl_staging
    if [[ $ssl_staging =~ ^[Yy]$ ]]; then
        SSL_STAGING="true"
    else
        SSL_STAGING="false"
    fi
    
    echo ""
}

# Prompt for Docker configuration
configure_docker() {
    echo -e "${CYAN}🐳 Docker Configuration${NC}"
    echo "============================"
    
    read -p "Enter Docker registry URL (optional): " DOCKER_REGISTRY
    
    if [[ -n "$DOCKER_REGISTRY" ]]; then
        read -p "Enter Docker username: " DOCKER_USERNAME
        read -s -p "Enter Docker password: " DOCKER_PASSWORD
        echo ""
    fi
    
    read -p "Enter Docker image prefix [app]: " DOCKER_IMAGE_PREFIX
    DOCKER_IMAGE_PREFIX=${DOCKER_IMAGE_PREFIX:-app}
    
    echo ""
}

# Prompt for monitoring configuration
configure_monitoring() {
    echo -e "${CYAN}📊 Monitoring Configuration${NC}"
    echo "================================="
    
    prompt_with_validation \
        "Enter Prometheus port" \
        "PROMETHEUS_PORT" \
        "validate_port" \
        "9090" \
        "Port for Prometheus metrics server"
    
    prompt_with_validation \
        "Enter Grafana port" \
        "GRAFANA_PORT" \
        "validate_port" \
        "3000" \
        "Port for Grafana dashboard"
    
    read -p "Enter Grafana admin username [admin]: " GRAFANA_ADMIN_USER
    GRAFANA_ADMIN_USER=${GRAFANA_ADMIN_USER:-admin}
    
    read -s -p "Enter Grafana admin password: " GRAFANA_ADMIN_PASSWORD
    echo ""
    
    if [[ -z "$GRAFANA_ADMIN_PASSWORD" ]]; then
        GRAFANA_ADMIN_PASSWORD="secure_password_here"
        warn "Using default password. Please change it after setup."
    fi
    
    echo ""
}

# Prompt for advanced configuration
configure_advanced() {
    echo -e "${CYAN}⚙️  Advanced Configuration${NC}"
    echo "==============================="
    
    read -p "Enter log level [info]: " LOG_LEVEL
    LOG_LEVEL=${LOG_LEVEL:-info}
    
    read -p "Enter log retention days [30]: " LOG_RETENTION_DAYS
    LOG_RETENTION_DAYS=${LOG_RETENTION_DAYS:-30}
    
    read -p "Enter backup retention days [7]: " BACKUP_RETENTION_DAYS
    BACKUP_RETENTION_DAYS=${BACKUP_RETENTION_DAYS:-7}
    
    read -p "Enter backup schedule (cron format) [0 2 * * *]: " BACKUP_SCHEDULE
    BACKUP_SCHEDULE=${BACKUP_SCHEDULE:-"0 2 * * *"}
    
    read -p "Enable firewall? (Y/n): " firewall_enabled
    if [[ $firewall_enabled =~ ^[Nn]$ ]]; then
        FIREWALL_ENABLED="false"
    else
        FIREWALL_ENABLED="true"
    fi
    
    read -p "Enter runner max concurrent jobs [4]: " RUNNER_MAX_CONCURRENT_JOBS
    RUNNER_MAX_CONCURRENT_JOBS=${RUNNER_MAX_CONCURRENT_JOBS:-4}
    
    read -p "Enter runner memory limit [4g]: " RUNNER_MEMORY_LIMIT
    RUNNER_MEMORY_LIMIT=${RUNNER_MEMORY_LIMIT:-4g}
    
    read -p "Enter runner CPU limit [2]: " RUNNER_CPU_LIMIT
    RUNNER_CPU_LIMIT=${RUNNER_CPU_LIMIT:-2}
    
    echo ""
}

# Prompt for notifications
configure_notifications() {
    echo -e "${CYAN}🔔 Notification Configuration${NC}"
    echo "=================================="
    
    read -p "Enter Slack webhook URL (optional): " SLACK_WEBHOOK_URL
    
    read -p "Enable email notifications? (y/N): " email_notifications
    if [[ $email_notifications =~ ^[Yy]$ ]]; then
        EMAIL_NOTIFICATIONS="true"
        
        read -p "Enter SMTP host [smtp.gmail.com]: " EMAIL_SMTP_HOST
        EMAIL_SMTP_HOST=${EMAIL_SMTP_HOST:-smtp.gmail.com}
        
        prompt_with_validation \
            "Enter SMTP port" \
            "EMAIL_SMTP_PORT" \
            "validate_port" \
            "587" \
            "SMTP port for email notifications"
        
        prompt_with_validation \
            "Enter email address" \
            "EMAIL_USER" \
            "validate_email" \
            "" \
            "Email address for sending notifications"
        
        read -s -p "Enter email password/app password: " EMAIL_PASSWORD
        echo ""
    else
        EMAIL_NOTIFICATIONS="false"
        EMAIL_SMTP_HOST="smtp.gmail.com"
        EMAIL_SMTP_PORT="587"
        EMAIL_USER="your-email@gmail.com"
        EMAIL_PASSWORD="your-app-password"
    fi
    
    echo ""
}

# Generate .env file
generate_env_file() {
    local env_file="$1"
    
    cat > "$env_file" << EOF
# GitHub Actions Runner Configuration
# Generated by configure.sh on $(date)

# GitHub Configuration
GITHUB_TOKEN=$GITHUB_TOKEN
GITHUB_REPOSITORY=$GITHUB_REPOSITORY
RUNNER_LABELS=$RUNNER_LABELS
RUNNER_NAME=$RUNNER_NAME
RUNNER_WORK_DIRECTORY=/home/github-runner/_work
RUNNER_USER=github-runner
RUNNER_GROUP=github-runner

# Production Server Configuration
PRODUCTION_HOST=$PRODUCTION_HOST
PRODUCTION_USER=$PRODUCTION_USER
PRODUCTION_PORT=$PRODUCTION_PORT
PRODUCTION_PATH=$PRODUCTION_PATH
PRODUCTION_BACKUP_PATH=$PRODUCTION_BACKUP_PATH

# Domain and SSL Configuration
DOMAIN_NAME=$DOMAIN_NAME
SSL_EMAIL=$SSL_EMAIL
SSL_STAGING=$SSL_STAGING
DOCKER_REGISTRY=$DOCKER_REGISTRY
DOCKER_USERNAME=$DOCKER_USERNAME
DOCKER_PASSWORD=$DOCKER_PASSWORD
DOCKER_IMAGE_PREFIX=$DOCKER_IMAGE_PREFIX

# Monitoring Configuration
PROMETHEUS_PORT=$PROMETHEUS_PORT
GRAFANA_PORT=$GRAFANA_PORT
GRAFANA_ADMIN_USER=$GRAFANA_ADMIN_USER
GRAFANA_ADMIN_PASSWORD=$GRAFANA_ADMIN_PASSWORD

# Logging and Backup Configuration
LOG_LEVEL=$LOG_LEVEL
LOG_RETENTION_DAYS=$LOG_RETENTION_DAYS
LOG_PATH=/var/log/github-runner
BACKUP_RETENTION_DAYS=$BACKUP_RETENTION_DAYS
BACKUP_SCHEDULE=$BACKUP_SCHEDULE
BACKUP_PATH=/var/backups

# Security Configuration
FIREWALL_ENABLED=$FIREWALL_ENABLED
SSH_KEY_PATH=/home/github-runner/.ssh/id_rsa
SSL_CERT_PATH=/etc/ssl/certs
SSL_KEY_PATH=/etc/ssl/private

# Runner Performance Configuration
RUNNER_MAX_CONCURRENT_JOBS=$RUNNER_MAX_CONCURRENT_JOBS
RUNNER_MEMORY_LIMIT=$RUNNER_MEMORY_LIMIT
RUNNER_CPU_LIMIT=$RUNNER_CPU_LIMIT

# Notification Configuration
SLACK_WEBHOOK_URL=$SLACK_WEBHOOK_URL
EMAIL_NOTIFICATIONS=$EMAIL_NOTIFICATIONS
EMAIL_SMTP_HOST=$EMAIL_SMTP_HOST
EMAIL_SMTP_PORT=$EMAIL_SMTP_PORT
EMAIL_USER=$EMAIL_USER
EMAIL_PASSWORD=$EMAIL_PASSWORD

# Environment Configuration
ENVIRONMENT=production
DEBUG_MODE=false
TEST_MODE=false
EOF
}

# Show configuration summary
show_summary() {
    echo -e "${CYAN}📋 Configuration Summary${NC}"
    echo "========================="
    echo ""
    echo -e "${GREEN}GitHub Configuration:${NC}"
    echo "  Repository: $GITHUB_REPOSITORY"
    echo "  Runner Name: $RUNNER_NAME"
    echo "  Labels: $RUNNER_LABELS"
    echo ""
    echo -e "${GREEN}Production Server:${NC}"
    echo "  Host: $PRODUCTION_HOST"
    echo "  User: $PRODUCTION_USER"
    echo "  Port: $PRODUCTION_PORT"
    echo "  Path: $PRODUCTION_PATH"
    echo ""
    echo -e "${GREEN}Domain & SSL:${NC}"
    echo "  Domain: $DOMAIN_NAME"
    echo "  Email: $SSL_EMAIL"
    echo "  Staging: $SSL_STAGING"
    echo ""
    echo -e "${GREEN}Monitoring:${NC}"
    echo "  Prometheus Port: $PROMETHEUS_PORT"
    echo "  Grafana Port: $GRAFANA_PORT"
    echo "  Grafana User: $GRAFANA_ADMIN_USER"
    echo ""
    echo -e "${GREEN}Advanced:${NC}"
    echo "  Log Level: $LOG_LEVEL"
    echo "  Firewall: $FIREWALL_ENABLED"
    echo "  Max Jobs: $RUNNER_MAX_CONCURRENT_JOBS"
    echo "  Email Notifications: $EMAIL_NOTIFICATIONS"
    echo ""
}

# Main configuration function
main() {
    show_banner
    
    info "Starting interactive configuration..."
    echo ""
    
    # Run configuration sections
    configure_github
    configure_production
    configure_domain
    configure_docker
    configure_monitoring
    configure_advanced
    configure_notifications
    
    # Show summary
    show_summary
    
    # Confirm configuration
    read -p "Do you want to save this configuration? (Y/n): " save_config
    if [[ $save_config =~ ^[Nn]$ ]]; then
        warn "Configuration cancelled"
        exit 0
    fi
    
    # Generate .env file
    local env_file=".env"
    if [[ -f "$env_file" ]]; then
        read -p "File .env already exists. Overwrite? (y/N): " overwrite
        if [[ ! $overwrite =~ ^[Yy]$ ]]; then
            env_file=".env.backup.$(date +%Y%m%d_%H%M%S)"
            warn "Saving as $env_file"
        fi
    fi
    
    generate_env_file "$env_file"
    log "Configuration saved to $env_file"
    
    echo ""
    echo -e "${GREEN}✅ Configuration complete!${NC}"
    echo ""
    info "Next steps:"
    echo "  1. Review the generated .env file"
    echo "  2. Transfer files to your Ubuntu server"
    echo "  3. Run: ./scripts/setup.sh"
    echo "  4. Run: ./scripts/register-runner.sh"
    echo "  5. Run: ./scripts/start-runner.sh"
    echo ""
    info "For detailed instructions, see docs/setup.md"
}

# Show help
show_help() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -h, --help     Show this help message"
    echo "  -v, --version  Show version information"
    echo ""
    echo "This script will guide you through configuring your GitHub Actions runner"
    echo "environment variables interactively."
    echo ""
    echo "Examples:"
    echo "  $0                    # Run interactive configuration"
    echo "  $0 --help            # Show help"
    echo ""
    echo "For more information, visit: https://github.com/mikemainguy/bldr"
}

# Get version from VERSION file
get_version() {
    if [[ -f "../VERSION" ]]; then
        cat ../VERSION
    elif [[ -f "VERSION" ]]; then
        cat VERSION
    else
        echo "1.0.0"
    fi
}

# Show version
show_version() {
    local version=$(get_version)
    echo "GitHub Actions Runner Configuration Script v$version"
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
                show_help
                exit 1
                ;;
            * )
                error "Unexpected argument: $1"
                show_help
                exit 1
                ;;
        esac
    done
}

# Handle interrupts gracefully
trap 'echo -e "\n${RED}Configuration interrupted${NC}"; exit 1' INT TERM

# Main execution
parse_args "$@"
main 