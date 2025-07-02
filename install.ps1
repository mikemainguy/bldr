# GitHub Actions Runner Installer for PowerShell
# This script can be installed and run with: irm https://raw.githubusercontent.com/mikemainguy/bldr/main/install.ps1 | iex

param(
    [string]$InstallDir = "$env:USERPROFILE\.bldr",
    [switch]$Help,
    [switch]$Version
)

# Colors for output
$Red = "Red"
$Green = "Green"
$Yellow = "Yellow"
$Blue = "Blue"
$Cyan = "Cyan"
$White = "White"

# Logging functions
function Write-Log {
    param([string]$Message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Write-Host "[$timestamp] $Message" -ForegroundColor $Green
}

function Write-Warn {
    param([string]$Message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Write-Host "[$timestamp] WARNING: $Message" -ForegroundColor $Yellow
}

function Write-Error {
    param([string]$Message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Write-Host "[$timestamp] ERROR: $Message" -ForegroundColor $Red
    exit 1
}

function Write-Info {
    param([string]$Message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Write-Host "[$timestamp] INFO: $Message" -ForegroundColor $Blue
}

# Banner
function Show-Banner {
    Write-Host @"
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
"@ -ForegroundColor $Cyan
}

# Show help
function Show-Help {
    Write-Host @"
Usage: .\install.ps1 [OPTIONS] [INSTALL_DIR]

Options:
  -Help              Show this help message
  -Version           Show version information

Arguments:
  INSTALL_DIR        Installation directory (default: ~/.bldr)

Examples:
  .\install.ps1                           # Install in ~/.bldr
.\install.ps1 -InstallDir C:\bldr       # Install in C:\bldr
  irm https://raw.githubusercontent.com/mikemainguy/bldr/main/install.ps1 | iex

For more information, visit: https://github.com/mikemainguy/bldr
"@
}

# Get version from VERSION file
function Get-Version {
    if (Test-Path "VERSION") {
        return (Get-Content "VERSION" -Raw).Trim()
    } else {
        return "1.0.0"
    }
}

# Show version
function Show-Version {
    $version = Get-Version
    Write-Host "GitHub Actions Runner Installer v$version"
    Write-Host "Copyright (c) 2024 Michael Mainguy"
    Write-Host "License: MIT"
}

# Check prerequisites
function Test-Prerequisites {
    Write-Log "Checking prerequisites..."
    
    # Check if Git is available
    try {
        $null = Get-Command git -ErrorAction Stop
        Write-Log "Git found"
    }
    catch {
        Write-Error "Git is required but not installed. Please install Git for Windows first."
    }
    
    # Check if PowerShell version is sufficient
    if ($PSVersionTable.PSVersion.Major -lt 5) {
        Write-Warn "PowerShell 5.0 or later recommended"
    }
    
    Write-Log "Prerequisites check passed"
}

# Get installation directory
function Set-InstallDirectory {
    param([string]$Path)
    
    if (-not $Path) {
        $Path = "$env:USERPROFILE\.bldr"
    }
    
    # Create installation directory
    if (-not (Test-Path $Path)) {
        New-Item -ItemType Directory -Path $Path -Force | Out-Null
    }
    
    Set-Location $Path
    Write-Log "Installation directory: $Path"
    return $Path
}

# Download repository
function Get-Repository {
    Write-Log "Downloading GitHub Actions runner setup..."
    
    # Repository URL (update this with your actual repository)
    $RepoUrl = "https://github.com/mikemainguy/bldr"
    
    # Check if directory already exists
    if (Test-Path "bldr") {
        Write-Warn "bldr directory already exists"
        $response = Read-Host "Do you want to overwrite it? (y/N)"
        if ($response -eq "y" -or $response -eq "Y") {
            Remove-Item -Recurse -Force "bldr"
        }
        else {
            Write-Error "Installation cancelled"
        }
    }
    
    # Clone repository
    try {
        git clone $RepoUrl bldr 2>$null
        Write-Log "Repository downloaded successfully"
    }
    catch {
        # Fallback: download as zip
        Write-Warn "Git clone failed, trying zip download..."
        try {
            $zipUrl = "$RepoUrl/archive/main.zip"
            $zipFile = "bldr.zip"
            
            Invoke-WebRequest -Uri $zipUrl -OutFile $zipFile
            Expand-Archive -Path $zipFile -DestinationPath "."
            Rename-Item "bldr-main" "bldr"
            Remove-Item $zipFile
            Write-Log "Repository downloaded successfully (zip)"
        }
        catch {
            Write-Error "Failed to download repository. Please check your internet connection."
        }
    }
    
    Set-Location "bldr"
}

# Setup environment
function Set-Environment {
    Write-Log "Setting up environment configuration..."
    
    # Copy environment template
    if (Test-Path "env.example") {
        Copy-Item "env.example" ".env"
        Write-Log "Environment template copied to .env"
        Write-Info "Please edit .env file with your configuration before continuing"
    }
    else {
        Write-Warn "env.example not found, creating basic .env file"
        New-BasicEnv
    }
}

# Create basic environment file
function New-BasicEnv {
    $envContent = @"
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
"@
    
    $envContent | Out-File -FilePath ".env" -Encoding UTF8
}

# Make scripts executable (for WSL/Linux compatibility)
function Set-ScriptsExecutable {
    Write-Log "Making scripts executable..."
    
    if (Test-Path "scripts") {
        Get-ChildItem "scripts\*.sh" | ForEach-Object {
            # Note: This is for WSL compatibility
            # In Windows, we just ensure the files exist
        }
        Write-Log "Scripts prepared for execution"
    }
    else {
        Write-Warn "Scripts directory not found"
    }
}

# Show next steps
function Show-NextSteps {
    Write-Host @"
╔══════════════════════════════════════════════════════════════╗
║                                                              ║
║    ✅ Installation Complete!                                 ║
║                                                              ║
║    Next Steps:                                               ║
║                                                              ║
║    1. Edit the .env file with your configuration:            ║
║       notepad .env                                           ║
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
"@ -ForegroundColor $Cyan
    
    Write-Log "Installation completed successfully!"
    Write-Log "Installation directory: $InstallDir\bldr"
    
    # Show important files
    Write-Host ""
    Write-Info "Important files:"
    Write-Host "  📄 .env                    - Environment configuration"
    Write-Host "  📄 README.md               - Quick start guide"
    Write-Host "  📄 docs/setup.md           - Detailed setup instructions"
    Write-Host "  📄 IMPLEMENTATION_PLAN.md  - Complete project plan"
    Write-Host "  🔧 scripts/                - Setup and management scripts"
    Write-Host "  📋 workflows/              - GitHub Actions workflow templates"
    
    Write-Host ""
    Write-Warn "⚠️  IMPORTANT: Edit .env file with your actual configuration before proceeding!"
}

# Main installation function
function Start-Installation {
    Show-Banner
    
    # Check prerequisites
    Test-Prerequisites
    
    # Get installation directory
    $InstallDir = Set-InstallDirectory $InstallDir
    
    # Download repository
    Get-Repository
    
    # Setup environment
    Set-Environment
    
    # Make scripts executable
    Set-ScriptsExecutable
    
    # Show next steps
    Show-NextSteps
}

# Handle parameters
if ($Help) {
    Show-Help
    exit 0
}

if ($Version) {
    Show-Version
    exit 0
}

# Check execution policy
$executionPolicy = Get-ExecutionPolicy
if ($executionPolicy -eq "Restricted") {
    Write-Warn "PowerShell execution policy is restricted."
    Write-Warn "You may need to run: Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser"
}

# Run installation
try {
    Start-Installation
}
catch {
    Write-Error "Installation failed: $($_.Exception.Message)"
    exit 1
} 