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

# GitHub Actions Local Runner Setup Script
# This script sets up a complete GitHub Actions runner environment on Ubuntu Linux

set -e

# Check if running as root
check_root() {
    if [[ $EUID -eq 0 ]]; then
        error "This script should not be run as root. Please run as a regular user with sudo privileges."
    fi
}

# Check Ubuntu version
check_ubuntu_version() {
    if [[ ! -f /etc/os-release ]]; then
        error "This script is designed for Ubuntu Linux only."
    fi
    
    source /etc/os-release
    if [[ "$ID" != "ubuntu" ]]; then
        error "This script is designed for Ubuntu Linux only. Detected: $ID"
    fi
    
    log "Detected Ubuntu version: $VERSION_ID"
}

# Update system packages
update_system() {
    log "Updating system packages..."
    sudo apt update && sudo apt upgrade -y
    log "System packages updated successfully."
}

# Install required packages
install_packages() {
    log "Installing required packages..."
    
    # Essential packages
    sudo apt install -y \
        curl \
        wget \
        git \
        jq \
        unzip \
        software-properties-common \
        apt-transport-https \
        gnupg \
        lsb-release \
        htop \
        vim \
        rsync \
        openssh-server \
    
    log "Required packages installed successfully."
}

# Install Docker
install_docker() {
    log "Installing Docker..."
    
    # Remove old versions
    sudo apt remove -y docker docker-engine docker.io containerd runc 2>/dev/null || true
    
    # Add Docker's official GPG key
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
    
    # Add Docker repository
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    
    # Install Docker
    sudo apt update
    sudo apt install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
    
    # Add user to docker group
    sudo usermod -aG docker $USER
    
    # Start and enable Docker
    sudo systemctl start docker
    sudo systemctl enable docker
    
    log "Docker installed successfully."
}

# Install Node.js
install_nodejs() {
    log "Installing Node.js..."
    
    # Install Node.js 18.x
    curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
    sudo apt install -y nodejs
    
    # Install global npm packages
    sudo npm install -g npm@latest yarn pm2
    
    log "Node.js installed successfully."
}

# Create runner user
create_runner_user() {
    log "Creating GitHub runner user..."
    
    if ! id "github-runner" &>/dev/null; then
        sudo useradd -m -s /bin/bash github-runner
        sudo usermod -aG docker github-runner
        log "GitHub runner user created successfully."
    else
        log "GitHub runner user already exists."
    fi
}

# Setup directories
setup_directories() {
    log "Setting up directories..."
    
    # Create necessary directories
    sudo mkdir -p /home/github-runner/_work
    sudo mkdir -p /home/github-runner/actions-runner
    sudo mkdir -p /var/log/github-runner
    sudo mkdir -p /var/backups
    sudo mkdir -p /etc/github-runner
    
    # Set permissions
    sudo chown -R github-runner:github-runner /home/github-runner
    sudo chown -R github-runner:github-runner /var/log/github-runner
    sudo chown -R github-runner:github-runner /var/backups
    
    # Create config directories
    mkdir -p config/runner
    mkdir -p scripts
    mkdir -p workflows
    mkdir -p docs
    mkdir -p logs
    
    log "Directories created successfully."
}

# Setup SSH keys
setup_ssh_keys() {
    log "Setting up SSH keys..."
    
    # Create SSH directory for runner
    sudo mkdir -p /home/github-runner/.ssh
    sudo chmod 700 /home/github-runner/.ssh
    
    # Generate SSH key if it doesn't exist
    if [[ ! -f /home/github-runner/.ssh/id_rsa ]]; then
        sudo -u github-runner ssh-keygen -t rsa -b 4096 -f /home/github-runner/.ssh/id_rsa -N ""
        log "SSH key generated successfully."
    else
        log "SSH key already exists."
    fi
    
    # Set proper permissions
    sudo chown -R github-runner:github-runner /home/github-runner/.ssh
    sudo chmod 600 /home/github-runner/.ssh/id_rsa
    sudo chmod 644 /home/github-runner/.ssh/id_rsa.pub
    
    log "SSH keys configured successfully."
}

# Setup log rotation
setup_log_rotation() {
    log "Setting up log rotation..."
    
    # (Logrotate config removed)
    
    log "Log rotation configured successfully."
}

# Setup environment file
setup_environment() {
    log "Setting up environment configuration..."
    
    if [[ ! -f .env ]]; then
        cp env.example .env
        warn "Please edit .env file with your specific configuration values."
    else
        log "Environment file already exists."
    fi
}

# Setup systemd service
setup_systemd_service() {
    log "Setting up systemd service..."
    
    sudo tee /etc/systemd/system/github-runner.service > /dev/null <<EOF
[Unit]
Description=GitHub Actions Runner
After=network.target docker.service
Requires=docker.service

[Service]
Type=simple
User=github-runner
Group=github-runner
WorkingDirectory=/home/github-runner
ExecStart=/usr/local/bin/docker-compose up
ExecStop=/usr/local/bin/docker-compose down
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF
    
    sudo systemctl daemon-reload
    sudo systemctl enable github-runner.service
    
    log "Systemd service configured successfully."
}

# Create bldr-uninstall symlink
create_uninstall_symlink() {
    local scripts_dir="$HOME/.local/bin"
    mkdir -p "$scripts_dir"
    ln -sf "$(pwd)/scripts/uninstall.sh" "$scripts_dir/bldr-uninstall"
    log "Created symlink: $scripts_dir/bldr-uninstall -> $(pwd)/scripts/uninstall.sh"
    if ! echo "$PATH" | grep -q "$scripts_dir"; then
        warn "$scripts_dir is not in your PATH. Add it to your shell profile to use bldr-uninstall globally."
    fi
}

# Main setup function
main() {
    log "Starting GitHub Actions Runner setup..."
    
    check_root
    check_ubuntu_version
    update_system
    install_packages
    install_docker
    install_nodejs
    create_runner_user
    setup_directories
    setup_ssh_keys
    setup_log_rotation
    setup_environment
    setup_systemd_service
    create_uninstall_symlink
    
    log "Setup completed successfully!"
    log "Next steps:"
    log "1. Edit .env file with your configuration"
    log "2. Run: ./scripts/register-runner.sh"
    log "3. Run: ./scripts/start-runner.sh"
    log ""
    log "Please reboot the system to ensure all changes take effect."
}

# Run main function
main "$@" 