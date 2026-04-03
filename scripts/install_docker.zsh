#!/bin/bash
set -e  # Exit immediately if any command returns a non-zero status

# Color definitions
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'  # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_step() {
    echo -e "\n${PURPLE}==>${NC} ${CYAN}$1${NC}"
}

# Configuration
USE_REGISTRY_MIRRORS=false
REGISTRY_MIRRORS=""

# Banner
echo -e "${CYAN}"
echo "  ____             _              "
echo " |  _ \  ___   ___| | _____ _ __  "
echo " | | | |/ _ \ / __| |/ / _ \ '__| "
echo " | |_| | (_) | (__|   <  __/ |    "
echo " |____/ \___/ \___|_|\_\___|_|    "
echo "                                  "
echo -e "${NC}"
echo -e "${YELLOW}Docker Universal Installer${NC} (2026 Edition)"
echo -e "${YELLOW}Compatible with:${NC} CentOS/RHEL, Ubuntu/Debian, Rocky Linux, AlmaLinux, Alpine"
echo -e "${YELLOW}Note:${NC} By default, uses official Docker Hub (no registry mirrors)"
echo "      Use --registry-mirror option for China/private mirrors\n"

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --registry-mirror=*)
            USE_REGISTRY_MIRRORS=true
            REGISTRY_MIRRORS="${1#*=}"
            shift
            ;;
        --china-mirrors)
            USE_REGISTRY_MIRRORS=true
            REGISTRY_MIRRORS="china"
            shift
            ;;
        -h|--help)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --registry-mirror=URL   Specify custom registry mirror URL"
            echo "  --china-mirrors         Enable China-optimized registry mirrors"
            echo "  -h, --help              Show this help message"
            echo ""
            echo "Examples:"
            echo "  $0                           # Use Docker Hub directly (default)"
            echo "  $0 --china-mirrors           # Enable China-optimized registry mirrors"
            echo "  $0 --registry-mirror=https://mirror.example.com  # Custom registry mirror"
            exit 0
            ;;
        *)
            log_error "Unknown option: $1"
            echo "Use $0 --help for usage information"
            exit 1
            ;;
    esac
done

# Display configuration
log_step "Configuration Summary"
if [ "$USE_REGISTRY_MIRRORS" = true ]; then
    if [ "$REGISTRY_MIRRORS" = "china" ]; then
        log_info "Using China-optimized registry mirrors"
    elif [ -n "$REGISTRY_MIRRORS" ]; then
        log_info "Using custom registry mirror: $REGISTRY_MIRRORS"
    fi
else
    log_info "No registry mirrors - using Docker Hub directly (default)"
    log_warning "If you're in China, image pulls may be slow. Use --china-mirrors option."
fi

log_step "1. System Check and Requirements"
log_info "Checking system information..."
OS_INFO=$(cat /etc/os-release 2>/dev/null | grep -E "^(NAME|VERSION_ID)=" || echo "NAME=Unknown")
OS_NAME=$(echo "$OS_INFO" | grep "NAME=" | cut -d= -f2 | tr -d '\"')
OS_VERSION=$(echo "$OS_INFO" | grep "VERSION_ID=" | cut -d= -f2 | tr -d '\"' 2>/dev/null || echo "Unknown")
log_info "Detected: $OS_NAME $OS_VERSION"
log_info "Current user: $USER"

# Check if user has sudo privileges
if ! sudo -v 2>/dev/null; then
    log_error "User $USER does not have sudo privileges or password is required"
    log_error "Please ensure you have sudo access before running this script"
    exit 1
fi

# 1. Check and install curl
if ! command -v curl &> /dev/null; then
    log_warning "curl not found. Installing..."
    if command -v apt-get &> /dev/null; then
        sudo apt-get update && sudo apt-get install -y curl
    elif command -v yum &> /dev/null; then
        sudo yum install -y curl
    elif command -v dnf &>/dev/null; then
        sudo dnf install -y curl
    elif command -v apk &>/dev/null; then
        sudo apk add --no-cache curl
    else
        log_error "Unsupported package manager. Please install curl manually."
        exit 1
    fi
    log_success "curl installed successfully"
fi

log_step "2. Download Docker Installation Script"
log_info "Downloading official Docker installation script..."
curl -fsSL https://get.docker.com -o get-docker.sh
log_success "Script downloaded: get-docker.sh"

log_step "3. Install Docker Engine (using official Docker repositories)"
log_info "Installing Docker from official repositories (may take a few minutes)..."
sudo sh get-docker.sh
log_success "Docker Engine installed successfully"

log_step "4. Start and Enable Docker Service"
log_info "Starting Docker service..."
sudo systemctl enable --now docker
if systemctl is-active --quiet docker; then
    log_success "Docker service started and enabled"
else
    log_error "Failed to start Docker service"
    exit 1
fi

log_step "5. Configure User Permissions"
if ! getent group docker | grep -q "\b$USER\b"; then
    sudo usermod -aG docker $USER
    log_success "User $USER added to docker group"
    log_warning "Re-login or run '${YELLOW}newgrp docker${NC}' for permission changes to take effect"
else
    log_info "User $USER is already in docker group"
fi

log_step "6. Configure Docker Daemon"
if [ "$USE_REGISTRY_MIRRORS" = true ]; then
    if [ "$REGISTRY_MIRRORS" = "china" ]; then
        # China-optimized registry mirrors
        log_info "Setting up China-optimized registry mirrors for faster image pulls..."
        sudo mkdir -p /etc/docker
        sudo tee /etc/docker/daemon.json <<-'EOF'
{
  "registry-mirrors": [
    "https://docker.xuanyuan.me",
    "https://mirror.ccs.tencentyun.com",
    "https://docker.mirrors.ustc.edu.cn",
    "https://hub-mirror.c.163.com"
  ],
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  },
  "live-restore": true,
  "storage-driver": "overlay2",
  "exec-opts": ["native.cgroupdriver=systemd"]
}
EOF
        log_success "Configured China registry mirrors"
    elif [ -n "$REGISTRY_MIRRORS" ]; then
        # Custom registry mirror
        log_info "Setting up custom registry mirror: $REGISTRY_MIRRORS"
        sudo mkdir -p /etc/docker
        sudo tee /etc/docker/daemon.json <<-EOF
{
  "registry-mirrors": ["$REGISTRY_MIRRORS"],
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  },
  "live-restore": true,
  "storage-driver": "overlay2",
  "exec-opts": ["native.cgroupdriver=systemd"]
}
EOF
        log_success "Configured custom registry mirror"
    fi

    # Restart Docker to apply configuration
    sudo systemctl daemon-reload
    sudo systemctl restart docker
    log_success "Docker daemon restarted with registry mirrors"
else
    # Basic configuration without registry mirrors
    log_info "Configuring Docker with basic settings (no registry mirrors)..."
    sudo mkdir -p /etc/docker
    sudo tee /etc/docker/daemon.json <<-'EOF'
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  },
  "live-restore": true,
  "storage-driver": "overlay2",
  "exec-opts": ["native.cgroupdriver=systemd"]
}
EOF
    sudo systemctl daemon-reload
    sudo systemctl restart docker
    log_success "Docker daemon configured (no registry mirrors)"
fi

log_step "7. Verify Installation"
log_info "Checking Docker version..."
DOCKER_VERSION=$(sudo docker version --format '{{.Server.Version}}' 2>/dev/null || echo "Unknown")
if [ "$DOCKER_VERSION" != "Unknown" ]; then
    log_success "Docker version: $DOCKER_VERSION"
else
    log_error "Failed to get Docker version"
    exit 1
fi

log_info "Checking Docker info..."
if sudo docker info &>/dev/null; then
    log_success "Docker is responding correctly"
else
    log_error "Docker is not responding"
    exit 1
fi

log_step "8. Test Docker Functionality"
log_info "Running hello-world test container..."
if sudo docker run --rm hello-world 2>&1 | grep -q "Hello from Docker!"; then
    log_success "✓ Docker installation verified successfully"
else
    log_warning "⚠ Docker test completed with warnings"
fi

log_step "9. Display Configuration Summary"

# 修复颜色显示 - 使用多个 echo 语句
echo ""
echo -e "${CYAN}╔══════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║                  Docker Installation Complete                    ║${NC}"
echo -e "${CYAN}╠══════════════════════════════════════════════════════════════════╣${NC}"
echo -e "${CYAN}║ Configuration Summary:                                           ║${NC}"
echo -e "${CYAN}║                                                                  ║${NC}"
echo -e "${CYAN}║  • Docker Version: $(printf '%-20s' "$DOCKER_VERSION")${NC}"
echo -e "${CYAN}║  • Service Status: $(systemctl is-active docker)${NC}"
echo -e "${CYAN}║  • Current User: $USER${NC}"

# Check if user is in docker group
if getent group docker | grep -q "\b$USER\b"; then
    echo -e "${CYAN}║  • User in docker group: ${GREEN}✓${CYAN}                          ║${NC}"
else
    echo -e "${CYAN}║  • User in docker group: ${RED}✗${CYAN}                           ║${NC}"
fi

if [ "$USE_REGISTRY_MIRRORS" = true ]; then
    echo -e "${CYAN}║  • Registry Mirrors: ${GREEN}Enabled${CYAN}                      ║${NC}"
else
    echo -e "${CYAN}║  • Registry Mirrors: ${YELLOW}Disabled${CYAN}                     ║${NC}"
fi

echo -e "${CYAN}║                                                                  ║${NC}"

if [ "$USE_REGISTRY_MIRRORS" = true ]; then
    if [ "$REGISTRY_MIRRORS" = "china" ]; then
        echo -e "${CYAN}║ China-optimized registry mirrors enabled:                      ║${NC}"
        echo -e "${CYAN}║  • https://docker.xuanyuan.me                      ║${NC}"
        echo -e "${CYAN}║  • https://mirror.ccs.tencentyun.com                ║${NC}"
        echo -e "${CYAN}║  • https://docker.mirrors.ustc.edu.cn               ║${NC}"
        echo -e "${CYAN}║  • https://hub-mirror.c.163.com                     ║${NC}"
    elif [ -n "$REGISTRY_MIRRORS" ]; then
        echo -e "${CYAN}║ Custom registry mirror:                                        ║${NC}"
        echo -e "${CYAN}║  • $REGISTRY_MIRRORS${NC}"
    fi
else
    echo -e "${CYAN}║ Registry: ${YELLOW}Using Docker Hub directly (no mirrors)${CYAN}       ║${NC}"
    echo -e "${CYAN}║ Tip: If in China, restart with --china-mirrors for faster pulls  ║${NC}"
fi

echo -e "${CYAN}║                                                                  ║${NC}"
echo -e "${CYAN}║ Important Next Steps:                                            ║${NC}"
echo -e "${CYAN}║  • Re-login or run: ${YELLOW}newgrp docker${CYAN}                       ║${NC}"
echo -e "${CYAN}║  • Test: ${YELLOW}docker run --rm alpine echo 'Docker ready!'${CYAN}       ║${NC}"
if [ "$USE_REGISTRY_MIRRORS" = true ]; then
    echo -e "${CYAN}║  • Check mirrors: ${YELLOW}docker info | grep -A 5 'Registry Mirrors'${CYAN} ║${NC}"
else
    echo -e "${CYAN}║  • Check config: ${YELLOW}docker info | grep -i 'registry'${CYAN}           ║${NC}"
fi
echo -e "${CYAN}║                                                                  ║${NC}"
echo -e "${CYAN}║ Need help? Run: ${YELLOW}docker --help${CYAN}                               ║${NC}"
echo -e "${CYAN}╚══════════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Cleanup
rm -f get-docker.sh
log_info "Cleaned up temporary files"

# Performance tips
log_step "10. Performance Tips"
if [ "$USE_REGISTRY_MIRRORS" = false ]; then
    log_warning "You're using Docker Hub directly."
    log_warning "If you're experiencing slow image pulls, consider:"
    log_warning "  - Rerun script with: $0 --china-mirrors"
    log_warning "  - Or add mirrors manually to /etc/docker/daemon.json"
fi

echo ""
echo -e "${YELLOW}To test your installation:${NC}"
echo "  docker run --rm alpine echo '✅ Docker is working!'"
echo ""
echo -e "${YELLOW}To test image pull speed:${NC}"
echo "  time docker pull alpine:latest"
echo ""
log_success "✅ Docker installation completed successfully!"