# GitHub Actions Local Runner for Ubuntu Linux

A comprehensive solution for running GitHub Actions locally on Ubuntu Linux with automated Node.js project deployment capabilities.

## Overview

This project provides a complete setup for running GitHub Actions self-hosted runners on Ubuntu Linux, specifically optimized for Node.js project deployments. The runner can be configured to automatically deploy Node.js applications when code is pushed to specific branches.

## Features

- **Self-hosted GitHub Actions Runner**: Run GitHub Actions workflows locally on Ubuntu Linux
- **Node.js Autodeployment**: Automatic deployment of Node.js projects on code changes
- **Docker Integration**: Containerized deployment for consistent environments
- **SSL/TLS Support**: Secure HTTPS deployments with Let's Encrypt
- **Security Hardening**: Security best practices and access controls

## Architecture

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   GitHub Repo   │    │  Local Runner   │    │  Production     │
│                 │────│  (Ubuntu)       │────│  Environment    │
│ - Push Code     │    │                 │    │                 │
│ - Create PR     │    │ - Runner Agent  │    │ - Node.js App   │
│ - Merge to Main │    │ - Docker Engine │    │ - Nginx Proxy   │
└─────────────────┘    │ - Auto Deploy   │    │ - SSL Cert      │
                       └─────────────────┘    └─────────────────┘
```

## Prerequisites

- Ubuntu 20.04 LTS or later
- Docker and Docker Compose
- Node.js 18+ and npm
- Git
- SSH access to production server
- GitHub CLI (gh) authenticated (run 'gh auth login')

## Quick Start

1. **Clone this repository**:
   ```bash
   git clone https://github.com/mikemainguy/bldr.git
   cd bldr
   ```

2. **Install bldr command symlinks**:
   ```bash
   ./scripts/install-links.sh
   # Make sure ~/.local/bin is in your PATH
   ```

3. **Run setup**:
   ```bash
   bldr-setup
   ```

4. **Configure your environment**:
   ```bash
   bldr-configure
   ```

5. **Register the runner**:
   ```bash
   bldr-register
   ```

6. **Uninstall (optional)**:
   ```bash
   bldr-uninstall
   ```

## Directory Structure

```
bldr/
├── README.md                 # This file
├── env.example              # Environment variables template
├── install.sh               # GitBash installation script
├── install.ps1              # PowerShell installation script
├── docker-compose.yml       # Docker services configuration
├── scripts/                 # Setup and management scripts
│   ├── configure.sh        # Interactive configuration wizard
│   ├── setup.sh            # Initial setup script
│   ├── register-runner.sh  # GitHub runner registration
│   ├── start-runner.sh     # Start runner service
│   ├── deploy.sh           # Deployment script
│   └── backup.sh           # Backup script (remove if not present)
├── config/                  # Configuration files
│   ├── nginx/              # Nginx configuration
│   ├── ssl/                # SSL certificates
│   └── runner/             # Runner configuration
├── workflows/              # GitHub Actions workflow templates
│   ├── nodejs-deploy.yml   # Node.js deployment workflow
│   └── security-scan.yml   # Security scanning workflow
├── docs/                   # Documentation
    ├── setup.md            # Detailed setup guide
    ├── deployment.md       # Deployment guide
    ├── troubleshooting.md  # Troubleshooting guide
    └── security.md         # Security considerations
```

## Installation Scripts

### Shell Script (`install.sh`)
A comprehensive installation script for Linux and macOS users.

**Features:**
- One-command installation
- Automatic repository download
- Environment configuration setup
- Prerequisites checking
- Cross-platform compatibility (Linux/macOS)

**Usage:**
```bash
# Install in default location (~/.bldr)
curl -sSL https://raw.githubusercontent.com/mikemainguy/bldr/main/install.sh | bash

# Install in custom location
curl -sSL https://raw.githubusercontent.com/mikemainguy/bldr/main/install.sh | bash -s /opt/bldr

# Show help
curl -sSL https://raw.githubusercontent.com/mikemainguy/bldr/main/install.sh | bash -s -- --help
```

## Configuration

### Interactive Configuration (Recommended)

The easiest way to configure your environment is using the interactive configuration script:

```bash
./scripts/configure.sh
```

This script will:
- Guide you through all required settings
- Validate input formats (emails, domains, etc.)
- Provide helpful tips and examples
- Generate a properly formatted `.env` file
- Show a summary of your configuration before saving

### Environment Variables

Key environment variables to configure:

- `GITHUB_TOKEN`: GitHub Personal Access Token
- `GITHUB_REPOSITORY`: Target repository (owner/repo)
- `RUNNER_LABELS`: Custom labels for the runner
- `PRODUCTION_HOST`: Production server hostname/IP
- `PRODUCTION_USER`: SSH user for production server
- `DOMAIN_NAME`: Domain name for SSL certificates
- `DOCKER_REGISTRY`: Docker registry for images

### Runner Configuration

The runner can be configured for:
- Specific repositories or organizations
- Custom labels for workflow targeting
- Resource limits and scheduling
- Security policies and access controls

## Deployment Workflow

1. **Code Push**: Developer pushes code to GitHub
2. **Workflow Trigger**: GitHub Actions workflow is triggered
3. **Local Runner**: Self-hosted runner picks up the job
4. **Build & Test**: Application is built and tested
5. **Docker Build**: Docker image is created and tagged
6. **Deploy**: Application is deployed locally in Docker
7. **Health Check**: Deployment is verified at http://localhost:3000/health
8. **Notification**: Success/failure notifications sent

## Security Considerations

- **Runner Isolation**: Each runner runs in isolated containers
- **Secret Management**: Secure handling of sensitive data
- **Network Security**: Firewall rules and network isolation
- **Access Control**: Role-based access and authentication
- **Audit Logging**: Comprehensive audit trails
- **Regular Updates**: Automated security updates

## Troubleshooting

Common issues and solutions:

1. **Runner not connecting**: Check network connectivity and GitHub CLI authentication
2. **Deployment failures**: Check Docker status and local container logs
3. **SSL certificate issues**: Check Let's Encrypt configuration
4. **Resource exhaustion**: Monitor system resources and adjust limits

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests if applicable
5. Submit a pull request

## License

MIT License - see LICENSE file for details

## Support

For issues and questions:
- Create an issue in this repository
- Check the troubleshooting guide
- Review the documentation in the `docs/` directory 