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
     ⚙️  GitHub Actions Runner Configuration v$version         
╔══════════════════════════════════════════════════════════════╗
║                                                              ║
║    Interactive Environment Setup                             ║
║                                                              ║
║    This script will guide you through configuring            ║
║    your GitHub Actions runner environment variables.         ║
║                                                              ║
╚══════════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
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
    echo ""
    info "This runner uses the GitHub CLI (gh) for authentication."
    info "Please ensure you are logged in with 'gh auth login' before proceeding."
    echo ""
    read -p "Press Enter to continue after you have authenticated with 'gh auth login'." _
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

# Generate .env file
generate_env_file() {
    local env_file="$1"
    
    cat > "$env_file" << EOF
# GitHub Actions Runner Configuration
# Generated by configure.sh on $(date)

# GitHub Configuration
GITHUB_REPOSITORY=$GITHUB_REPOSITORY
RUNNER_LABELS=$RUNNER_LABELS
RUNNER_NAME=$RUNNER_NAME
RUNNER_WORK_DIRECTORY=/home/github-runner/_work
RUNNER_USER=github-runner
RUNNER_GROUP=github-runner


DOCKER_REGISTRY=$DOCKER_REGISTRY
DOCKER_USERNAME=$DOCKER_USERNAME
DOCKER_PASSWORD=$DOCKER_PASSWORD
DOCKER_IMAGE_PREFIX=$DOCKER_IMAGE_PREFIX

# Logging and Backup Configuration
LOG_LEVEL=$LOG_LEVEL
LOG_RETENTION_DAYS=$LOG_RETENTION_DAYS
LOG_PATH=/var/log/github-runner
BACKUP_RETENTION_DAYS=$BACKUP_RETENTION_DAYS
BACKUP_SCHEDULE=$BACKUP_SCHEDULE
BACKUP_PATH=/var/backups

# Runner Performance Configuration
RUNNER_MAX_CONCURRENT_JOBS=$RUNNER_MAX_CONCURRENT_JOBS
RUNNER_MEMORY_LIMIT=$RUNNER_MEMORY_LIMIT
RUNNER_CPU_LIMIT=$RUNNER_CPU_LIMIT

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
}

# Main configuration function
main() {
    show_banner
    
    info "Starting interactive configuration..."
    echo ""
    
    # Run configuration sections
    configure_github
    configure_docker
    
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
    read -p "Would you like to automatically register the runner now? (Y/n): " auto_register
    if [[ ! $auto_register =~ ^[Nn]$ ]]; then
        if [[ -x "./scripts/register-runner.sh" ]]; then
            echo -e "${CYAN}Registering the runner...${NC}"
            ./scripts/register-runner.sh
        else
            echo -e "${RED}register-runner.sh not found or not executable. Please run it manually.${NC}"
        fi
    else
        echo -e "${YELLOW}You can register the runner later by running: ./scripts/register-runner.sh${NC}"
    fi
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