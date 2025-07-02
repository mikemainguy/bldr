#!/bin/bash

# GitHub Personal Access Token Generator
# Automates token creation using GitHub CLI or provides manual instructions

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

# Check if GitHub CLI is installed
check_gh_cli() {
    if command -v gh &> /dev/null; then
        return 0
    else
        return 1
    fi
}

# Install GitHub CLI
install_gh_cli() {
    log "Installing GitHub CLI..."
    
    case "$(uname -s)" in
        Linux*)
            if command -v apt-get &> /dev/null; then
                # Ubuntu/Debian
                curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
                echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
                sudo apt-get update
                sudo apt-get install -y gh
            elif command -v yum &> /dev/null; then
                # RHEL/CentOS
                sudo yum install -y gh
            elif command -v dnf &> /dev/null; then
                # Fedora
                sudo dnf install -y gh
            else
                error "Unsupported Linux distribution for automatic installation"
                return 1
            fi
            ;;
        Darwin*)
            # macOS
            if command -v brew &> /dev/null; then
                brew install gh
            else
                error "Homebrew not found. Please install Homebrew first or install gh manually"
                return 1
            fi
            ;;
        *)
            error "Unsupported OS for automatic installation"
            return 1
            ;;
    esac
    
    log "GitHub CLI installed successfully"
}

# Authenticate with GitHub CLI
authenticate_gh() {
    log "Authenticating with GitHub..."
    
    if gh auth status &> /dev/null; then
        log "Already authenticated with GitHub"
        return 0
    fi
    
    info "You'll be prompted to authenticate with GitHub in your browser"
    gh auth login --web
}

# Create Personal Access Token using GitHub CLI
create_token_with_gh() {
    local token_name="$1"
    local scopes="$2"
    local expiry="$3"
    
    log "Creating Personal Access Token: $token_name"
    
    # Create token with specified scopes and expiry
    local token_output
    token_output=$(gh auth token create --name "$token_name" --scopes "$scopes" --expiry "$expiry" --output json 2>/dev/null)
    
    if [[ $? -eq 0 ]]; then
        # Extract token from JSON output
        local token=$(echo "$token_output" | grep -o '"token":"[^"]*"' | cut -d'"' -f4)
        if [[ -n "$token" ]]; then
            echo "$token"
            return 0
        fi
    fi
    
    return 1
}

# Manual token creation instructions
show_manual_instructions() {
    echo ""
    echo -e "${CYAN}📝 Manual Token Creation Instructions${NC}"
    echo "============================================="
    echo ""
    echo "1. Go to GitHub Settings:"
    echo "   https://github.com/settings/tokens"
    echo ""
    echo "2. Click 'Generate new token (classic)'"
    echo ""
    echo "3. Configure the token:"
    echo "   - Note: 'bldr-github-runner' (or your preferred name)"
    echo "   - Expiration: 90 days (recommended)"
    echo ""
    echo "4. Select scopes:"
    echo "   ✅ repo (Full control of private repositories)"
    echo "   ✅ admin:org (Full control of orgs and teams)"
    echo "   ✅ workflow (Update GitHub Action workflows)"
    echo ""
    echo "5. Click 'Generate token'"
    echo ""
    echo "6. Copy the token (you won't see it again!)"
    echo ""
    warn "⚠️  Keep this token secure and never share it!"
}

# Main function
main() {
    local token_name="${1:-bldr-github-runner}"
    local scopes="${2:-repo,admin:org,workflow}"
    local expiry="${3:-90d}"
    
    echo -e "${CYAN}🔑 GitHub Personal Access Token Generator${NC}"
    echo "============================================="
    echo ""
    
    # Check if GitHub CLI is available
    if check_gh_cli; then
        log "GitHub CLI found"
        
        # Authenticate if needed
        if authenticate_gh; then
            # Try to create token automatically
            log "Attempting to create token automatically..."
            local token
            token=$(create_token_with_gh "$token_name" "$scopes" "$expiry")
            
            if [[ $? -eq 0 ]] && [[ -n "$token" ]]; then
                echo ""
                echo -e "${GREEN}✅ Token created successfully!${NC}"
                echo ""
                echo "Token Name: $token_name"
                echo "Scopes: $scopes"
                echo "Expiry: $expiry"
                echo ""
                echo -e "${YELLOW}Your GitHub Personal Access Token:${NC}"
                echo "$token"
                echo ""
                warn "⚠️  Save this token securely - you won't see it again!"
                echo ""
                info "You can now use this token in your .env file:"
                echo "GITHUB_TOKEN=$token"
                echo ""
                return 0
            else
                warn "Automatic token creation failed, showing manual instructions"
            fi
        else
            warn "GitHub CLI authentication failed, showing manual instructions"
        fi
    else
        info "GitHub CLI not found"
        read -p "Would you like to install GitHub CLI for automatic token creation? (Y/n): " install_gh
        
        if [[ $install_gh =~ ^[Nn]$ ]]; then
            show_manual_instructions
            return 0
        fi
        
        if install_gh_cli; then
            # Retry the main process
            main "$@"
            return $?
        else
            warn "GitHub CLI installation failed, showing manual instructions"
        fi
    fi
    
    show_manual_instructions
}

# Show help
show_help() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -n, --name NAME     Token name (default: bldr-github-runner)"
    echo "  -s, --scopes SCOPES Comma-separated scopes (default: repo,admin:org,workflow)"
    echo "  -e, --expiry DAYS   Expiry in days (default: 90d)"
    echo "  -h, --help          Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0                                    # Use defaults"
    echo "  $0 -n my-runner-token                # Custom name"
    echo "  $0 -s repo,workflow -e 30d           # Custom scopes and expiry"
    echo ""
    echo "Scopes:"
    echo "  repo         - Full control of private repositories"
    echo "  admin:org    - Full control of orgs and teams"
    echo "  workflow     - Update GitHub Action workflows"
    echo "  read:org     - Read org data (if admin:org not needed)"
    echo ""
}

# Parse command line arguments
parse_args() {
    local token_name="bldr-github-runner"
    local scopes="repo,admin:org,workflow"
    local expiry="90d"
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            -n|--name)
                token_name="$2"
                shift 2
                ;;
            -s|--scopes)
                scopes="$2"
                shift 2
                ;;
            -e|--expiry)
                expiry="$2"
                shift 2
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            -*)
                error "Unknown option: $1"
                show_help
                exit 1
                ;;
            *)
                error "Unexpected argument: $1"
                show_help
                exit 1
                ;;
        esac
    done
    
    main "$token_name" "$scopes" "$expiry"
}

# Handle interrupts gracefully
trap 'echo -e "\n${RED}Token generation interrupted${NC}"; exit 1' INT TERM

# Main execution
parse_args "$@" 