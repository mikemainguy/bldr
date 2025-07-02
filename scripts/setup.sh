#!/bin/bash

# GitHub Actions Local Runner Setup Script
# This script sets up a complete GitHub Actions runner environment on Ubuntu Linux

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
        unzip \
        software-properties-common \
        apt-transport-https \
        ca-certificates \
        gnupg \
        lsb-release \
        htop \
        vim \
        ufw \
        fail2ban \
        logrotate \
        cron \
        rsync \
        openssh-server \
        nginx \
        certbot \
        python3-certbot-nginx
    
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
    mkdir -p config/{nginx,ssl,runner,grafana,prometheus,redis,postgres}
    mkdir -p scripts
    mkdir -p workflows
    mkdir -p monitoring
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

# Setup firewall
setup_firewall() {
    log "Setting up firewall..."
    
    # Reset firewall
    sudo ufw --force reset
    
    # Default policies
    sudo ufw default deny incoming
    sudo ufw default allow outgoing
    
    # Allow SSH
    sudo ufw allow ssh
    
    # Allow HTTP and HTTPS
    sudo ufw allow 80/tcp
    sudo ufw allow 443/tcp
    
    # Allow Docker ports
    sudo ufw allow 3000/tcp  # Grafana
    sudo ufw allow 9090/tcp  # Prometheus
    sudo ufw allow 9100/tcp  # Node Exporter
    sudo ufw allow 8080/tcp  # cAdvisor
    
    # Enable firewall
    sudo ufw --force enable
    
    log "Firewall configured successfully."
}

# Setup fail2ban
setup_fail2ban() {
    log "Setting up fail2ban..."
    
    # Create fail2ban configuration
    sudo tee /etc/fail2ban/jail.local > /dev/null <<EOF
[DEFAULT]
bantime = 3600
findtime = 600
maxretry = 3

[sshd]
enabled = true
port = ssh
filter = sshd
logpath = /var/log/auth.log
maxretry = 3

[nginx-http-auth]
enabled = true
filter = nginx-http-auth
port = http,https
logpath = /var/log/nginx/error.log
maxretry = 3
EOF
    
    # Restart fail2ban
    sudo systemctl restart fail2ban
    sudo systemctl enable fail2ban
    
    log "Fail2ban configured successfully."
}

# Setup log rotation
setup_log_rotation() {
    log "Setting up log rotation..."
    
    sudo tee /etc/logrotate.d/github-runner > /dev/null <<EOF
/var/log/github-runner/*.log {
    daily
    missingok
    rotate 30
    compress
    delaycompress
    notifempty
    create 644 github-runner github-runner
    postrotate
        systemctl reload nginx > /dev/null 2>&1 || true
    endscript
}
EOF
    
    log "Log rotation configured successfully."
}

# Setup monitoring
setup_monitoring() {
    log "Setting up monitoring..."
    
    # Create Prometheus configuration
    cat > config/prometheus.yml <<EOF
global:
  scrape_interval: 15s
  evaluation_interval: 15s

rule_files:
  # - "first_rules.yml"
  # - "second_rules.yml"

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']

  - job_name: 'node-exporter'
    static_configs:
      - targets: ['localhost:9100']

  - job_name: 'cadvisor'
    static_configs:
      - targets: ['localhost:8080']

  - job_name: 'github-runner'
    static_configs:
      - targets: ['localhost:9100']
EOF
    
    log "Monitoring configured successfully."
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
    setup_firewall
    setup_fail2ban
    setup_log_rotation
    setup_monitoring
    setup_environment
    setup_systemd_service
    
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