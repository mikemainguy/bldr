# GitHub Actions Runner Setup Guide

This guide provides detailed instructions for setting up a GitHub Actions self-hosted runner on Ubuntu Linux for automated Node.js deployment.

## Prerequisites

Before starting the setup, ensure you have:

- Ubuntu 20.04 LTS or later
- Sudo privileges
- Internet connectivity
- GitHub CLI (gh) authenticated (run 'gh auth login')
- Domain name (optional, for SSL certificates)
- Production server with SSH access

## Step 1: System Preparation

### Update System Packages

```bash
sudo apt update && sudo apt upgrade -y
```

### Install Essential Packages

```bash
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
    openssh-server
```

## Step 2: Install Docker

### Remove Old Docker Versions

```bash
sudo apt remove -y docker docker-engine docker.io containerd runc 2>/dev/null || true
```

### Add Docker's Official GPG Key

```bash
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
```

### Add Docker Repository

```bash
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
```

### Install Docker

```bash
sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
```

### Add User to Docker Group

```bash
sudo usermod -aG docker $USER
```

### Start and Enable Docker

```bash
sudo systemctl start docker
sudo systemctl enable docker
```

## Step 3: Install Node.js

### Add NodeSource Repository

```bash
curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
```

### Install Node.js

```bash
sudo apt install -y nodejs
```

### Install Global NPM Packages

```bash
sudo npm install -g npm@latest yarn pm2
```

## Step 4: Clone and Setup Runner

### Clone the Repository

```bash
git clone https://github.com/mikemainguy/bldr.git
cd bldr
```

### Make Scripts Executable

```bash
chmod +x scripts/*.sh
```

### Configure Environment

```bash
cp env.example .env
```

Edit the `.env` file with your specific configuration:

```bash
nano .env
```

Key variables to configure:

- `GITHUB_REPOSITORY`: Target repository (owner/repo)
- `PRODUCTION_HOST`: Production server hostname/IP
- `PRODUCTION_USER`: SSH user for production server
- `DOMAIN_NAME`: Your domain name (for SSL)
- `DOCKER_REGISTRY`: Docker registry URL
- `DOCKER_USERNAME`: Docker registry username
- `DOCKER_PASSWORD`: Docker registry password

## Step 5: Run Setup Script

### Execute Setup Script

```bash
./scripts/setup.sh
```

This script will:

1. Update system packages
2. Install required dependencies
3. Create GitHub runner user
4. Setup directories and permissions
5. Configure SSH keys
6. Setup firewall and security
7. Create systemd service

### Reboot System

```bash
sudo reboot
```

After reboot, log back in and continue.

## Step 6: Register GitHub Actions Runner

### Run Registration Script

```bash
./scripts/register-runner.sh
```

This script will:

1. Download the latest GitHub Actions runner
2. Configure the runner with your repository
3. Install the runner as a system service
4. Test the connection to GitHub

## Step 7: Start the Runner

### Start All Services

```bash
./scripts/start-runner.sh
```

This script will:

1. Start Docker services
2. Start the GitHub Actions runner
3. Configure SSL certificates
4. Setup backup schedules

## Step 8: Verify Installation

### Check Service Status

```bash
# Check Docker services
docker-compose ps

# Check GitHub runner service
sudo systemctl status actions.runner.*

# Check if runner is connected
gh api repos/$GITHUB_REPOSITORY/actions/runners
```

## Step 9: Configure GitHub Repository

### Add Repository Secrets

In your GitHub repository, go to Settings > Secrets and variables > Actions and add:

- `DOCKER_REGISTRY`: Your Docker registry URL
- `DOCKER_USERNAME`: Docker registry username
- `DOCKER_PASSWORD`: Docker registry password
- `DOMAIN_NAME`: Your domain name
- `PRODUCTION_HOST`: Production server hostname
- `PRODUCTION_USER`: SSH user for production
- `SLACK_WEBHOOK_URL`: Slack webhook URL (optional)
- `SNYK_TOKEN`: Snyk security token (optional)

### Add Workflow File

Copy the workflow template to your repository:

```bash
cp workflows/nodejs-deploy.yml .github/workflows/
```

## Step 10: Test Deployment

### Create Test Application

Create a simple Node.js application to test the deployment:

```bash
mkdir test-app
cd test-app
npm init -y
npm install express
```

Create `app.js`:

```javascript
const express = require('express');
const app = express();
const port = process.env.PORT || 3000;

app.get('/health', (req, res) => {
  res.json({ status: 'healthy', timestamp: new Date().toISOString() });
});

app.get('/', (req, res) => {
  res.json({ message: 'Hello from GitHub Actions Runner!' });
});

app.listen(port, () => {
  console.log(`App listening at http://localhost:${port}`);
});
```

### Push to GitHub

```bash
git init
git add .
git commit -m "Initial commit"
git branch -M main
git remote add origin https://github.com/mikemainguy/bldr.git
git push -u origin main
```

## Troubleshooting

### Common Issues

1. **Runner not connecting to GitHub**
   - Check GitHub CLI authentication (run 'gh auth status')

2. **Docker permission errors**
   - Ensure user is in docker group
   - Restart Docker service
   - Log out and back in

3. **SSL certificate issues**
   - Verify domain DNS settings
   - Check certbot configuration
   - Ensure port 80 is accessible

4. **Deployment failures**
   - Check Docker status and local container logs

### Useful Commands

```bash
# View runner logs
sudo journalctl -u actions.runner.* -f

# View Docker logs
docker-compose logs -f

# Restart runner
sudo systemctl restart actions.runner.*

# Check runner status
sudo systemctl status actions.runner.*

# Unregister runner
cd /home/github-runner/actions-runner
sudo -u github-runner ./config.sh remove --unattended
```

## Security Considerations

1. **Firewall Configuration**
   - Only necessary ports are open
   - SSH access is restricted
   - Fail2ban is configured

2. **SSL/TLS**
   - Let's Encrypt certificates
   - Automatic renewal
   - Strong cipher configuration

3. **Access Control**
   - Dedicated runner user
   - Limited permissions
   - SSH key authentication

## Next Steps

After successful setup:

1. Configure your Node.js applications
2. Configure backup strategies
3. Set up disaster recovery procedures
4. Document your deployment processes

## Support

For issues and questions:

1. Check the troubleshooting guide
2. Review the logs in `/var/log/github-runner/`
3. Check GitHub Actions runner documentation
4. Create an issue in this repository 

6. **Deploy**: Application is deployed locally in Docker
7. **Health Check**: Deployment is verified at http://localhost:3000/health 