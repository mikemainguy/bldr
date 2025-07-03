#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/logging.sh"

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

log() { echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] INFO: $1${NC}"; }
warn() { echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] WARN: $1${NC}"; }
error() { echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ERROR: $1${NC}" >&2; }
info() { echo -e "${CYAN}$1${NC}"; }

# Banner
show_banner() {
    echo -e "${CYAN}"
    cat << 'EOF'
╔══════════════════════════════════════════════════════════════╗
║                                                              ║
║    🧹 bldr Uninstaller                                        ║
║                                                              ║
║    This will remove bldr, its symlinks, and optionally PATH. ║
║                                                              ║
╚══════════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
}

# Confirm uninstall
yesno_confirm() {
    read -p "$1 (y/N): " confirm
    if [[ ! $confirm =~ ^[Yy]$ ]]; then
        warn "Uninstall cancelled."
        exit 0
    fi
}

# Remove symlinks
remove_symlinks() {
    local scripts_dir="$HOME/.local/bin"
    local removed=()
    for link in bldr-configure bldr-token bldr-uninstall; do
        if [[ -L "$scripts_dir/$link" ]]; then
            rm "$scripts_dir/$link"
            log "Removed symlink: $scripts_dir/$link"
            removed+=("$scripts_dir/$link")
        fi
    done
    if [[ ${#removed[@]} -eq 0 ]]; then
        warn "No bldr symlinks found in $scripts_dir."
    fi
}

# Remove bldr directory
remove_bldr_dir() {
    local bldr_dir="$HOME/.bldr"
    if [[ -d "$bldr_dir" ]]; then
        rm -rf "$bldr_dir"
        log "Removed bldr directory: $bldr_dir"
    else
        warn "bldr directory not found at $bldr_dir."
    fi
}

# Remove PATH export from shell profile
remove_path_export() {
    local shell_name=$(basename "$SHELL")
    local profile_file=""
    case "$shell_name" in
        bash)
            if [[ -f "$HOME/.bashrc" ]]; then profile_file="$HOME/.bashrc"; fi
            ;;
        zsh)
            if [[ -f "$HOME/.zshrc" ]]; then profile_file="$HOME/.zshrc"; fi
            ;;
        fish)
            if [[ -f "$HOME/.config/fish/config.fish" ]]; then profile_file="$HOME/.config/fish/config.fish"; fi
            ;;
    esac
    if [[ -n "$profile_file" ]]; then
        if grep -q '# Added by bldr installer' "$profile_file"; then
            yesno_confirm "Remove PATH export from $profile_file?"
            sed -i.bak '/# Added by bldr installer/,+1d' "$profile_file"
            log "Removed PATH export from $profile_file (backup: $profile_file.bak)"
        else
            warn "No bldr PATH export found in $profile_file."
        fi
    else
        warn "Could not determine shell profile file."
    fi
}

# Main
show_banner
info "This will remove bldr, its symlinks, and optionally PATH modifications."
yesno_confirm "Are you sure you want to uninstall bldr and remove all related files?"

remove_symlinks
remove_bldr_dir

info ""
yesno_confirm "Would you like to remove the bldr PATH export from your shell profile? (Recommended if you won't reinstall)"
remove_path_export

info ""
echo -e "${GREEN}✅ bldr has been uninstalled. You may need to restart your terminal for all changes to take effect.${NC}" 