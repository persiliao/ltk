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
USE_CHINA_MIRROR=false
INSTALL_DIR="${HOME}/.linuxbrew"  # Default Homebrew install location for Linux

# Banner
echo -e "${CYAN}"
echo "  _   _                      _                      "
echo " | | | | ___  _ __ ___   ___| |__  _ __ _____      __"
echo " | |_| |/ _ \| '_ \` _ \ / _ \ '_ \| '__/ _ \ \ /\ / /"
echo " |  _  | (_) | | | | | |  __/ |_) | | |  __/\ V  V / "
echo " |_| |_|\___/|_| |_| |_|\___|_.__/|_|  \___| \_/\_/  "
echo "                                                    "
echo -e "${NC}"
echo -e "${YELLOW}Homebrew Linux Installer${NC}"
echo -e "${YELLOW}Compatible with:${NC} Linux (x86_64, aarch64)"
echo -e "${YELLOW}Note:${NC} Installs to ${YELLOW}${INSTALL_DIR}${NC} by default"
echo "      Use --china-mirror for faster installation in China\n"

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --china-mirror)
            USE_CHINA_MIRROR=true
            shift
            ;;
        --install-dir=*)
            INSTALL_DIR="${1#*=}"
            shift
            ;;
        -h|--help)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --china-mirror       Use China mirror for faster installation"
            echo "  --install-dir=PATH   Custom installation directory (default: ~/.linuxbrew)"
            echo "  -h, --help           Show this help message"
            echo ""
            echo "Examples:"
            echo "  $0                          # Standard installation"
            echo "  $0 --china-mirror           # Use China mirror"
            echo "  $0 --install-dir=/opt/homebrew  # Install to custom location"
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
log_info "Installation directory: $INSTALL_DIR"
if [ "$USE_CHINA_MIRROR" = true ]; then
    log_info "Using China mirror: Tsinghua Tuna mirror"
else
    log_info "Using official GitHub repositories"
fi

log_step "1. System Requirements Check"
log_info "Checking system architecture..."
ARCH=$(uname -m)
if [[ "$ARCH" != "x86_64" && "$ARCH" != "aarch64" ]]; then
    log_error "Unsupported architecture: $ARCH"
    log_error "Homebrew requires x86_64 or aarch64"
    exit 1
fi
log_success "Architecture: $ARCH"

log_info "Checking for required commands..."
for cmd in curl git; do
    if ! command -v $cmd &> /dev/null; then
        log_warning "$cmd not found. Installing..."

        if command -v apt-get &> /dev/null; then
            sudo apt-get update && sudo apt-get install -y $cmd
        elif command -v yum &> /dev/null; then
            sudo yum install -y $cmd
        elif command -v dnf &>/dev/null; then
            sudo dnf install -y $cmd
        elif command -v pacman &>/dev/null; then
            sudo pacman -Sy --noconfirm $cmd
        elif command -v zypper &>/dev/null; then
            sudo zypper install -y $cmd
        elif command -v apk &>/dev/null; then
            sudo apk add --no-cache $cmd
        else
            log_error "Unsupported package manager. Please install $cmd manually."
            exit 1
        fi
        log_success "$cmd installed"
    else
        log_info "$cmd: Found"
    fi
done

log_step "2. Install Dependencies"
log_info "Installing build dependencies..."

DEPENDENCIES="build-essential file procps"

if command -v apt-get &> /dev/null; then
    sudo apt-get update
    sudo apt-get install -y $DEPENDENCIES
elif command -v yum &> /dev/null; then
    sudo yum groupinstall -y "Development Tools"
    sudo yum install -y file procps-ng
elif command -v dnf &>/dev/null; then
    sudo dnf groupinstall -y "Development Tools"
    sudo dnf install -y file procps-ng
elif command -v pacman &>/dev/null; then
    sudo pacman -Sy --noconfirm base-devel file procps-ng
elif command -v zypper &>/dev/null; then
    sudo zypper install -y -t pattern devel_basis
    sudo zypper install -y file procps
elif command -v apk &>/dev/null; then
    sudo apk add --no-cache build-base file procps
else
    log_warning "Could not install build dependencies automatically"
    log_warning "Please ensure you have: gcc, make, git, curl, file, procps"
fi
log_success "Dependencies installed"

log_step "3. Set Installation Directory"
log_info "Creating installation directory: $INSTALL_DIR"
mkdir -p "$INSTALL_DIR"
if [ $? -ne 0 ]; then
    log_error "Failed to create installation directory"
    exit 1
fi
log_success "Directory created"

log_step "4. Clone Homebrew"
log_info "Cloning Homebrew repository..."
if [ "$USE_CHINA_MIRROR" = true ]; then
    # Use Tsinghua Tuna mirror for China users
    BREW_REPO="https://mirrors.tuna.tsinghua.edu.cn/git/homebrew/brew.git"
else
    # Official GitHub repository
    BREW_REPO="https://github.com/Homebrew/brew.git"
fi

git clone "$BREW_REPO" "$INSTALL_DIR"
if [ $? -ne 0 ]; then
    log_error "Failed to clone Homebrew repository"
    exit 1
fi
log_success "Homebrew cloned to $INSTALL_DIR"

log_step "5. Set Up Environment"
log_info "Configuring shell environment..."

# Determine shell
SHELL_NAME=$(basename "$SHELL")

# Add Homebrew to PATH
case "$SHELL_NAME" in
    bash)
        SHELL_RC="$HOME/.bashrc"
        ;;
    zsh)
        SHELL_RC="$HOME/.zshrc"
        ;;
    fish)
        SHELL_RC="$HOME/.config/fish/config.fish"
        ;;
    *)
        log_warning "Unknown shell: $SHELL_NAME"
        log_info "Defaulting to .bashrc"
        SHELL_RC="$HOME/.bashrc"
        ;;
esac

# Check if Homebrew is already in PATH
if ! grep -q "HOMEBREW_PREFIX" "$SHELL_RC" 2>/dev/null; then
    log_info "Adding Homebrew to $SHELL_RC"

    if [[ "$SHELL_NAME" == "fish" ]]; then
        echo "# Homebrew" >> "$SHELL_RC"
        echo "set -gx HOMEBREW_PREFIX '$INSTALL_DIR'" >> "$SHELL_RC"
        echo "set -gx HOMEBREW_CELLAR '$INSTALL_DIR/Cellar'" >> "$SHELL_RC"
        echo "set -gx HOMEBREW_REPOSITORY '$INSTALL_DIR'" >> "$SHELL_RC"
        echo "fish_add_path $INSTALL_DIR/bin" >> "$SHELL_RC"
    else
        echo "# Homebrew" >> "$SHELL_RC"
        echo "export HOMEBREW_PREFIX='$INSTALL_DIR'" >> "$SHELL_RC"
        echo "export HOMEBREW_CELLAR='$INSTALL_DIR/Cellar'" >> "$SHELL_RC"
        echo "export HOMEBREW_REPOSITORY='$INSTALL_DIR'" >> "$SHELL_RC"
        echo "export PATH='$INSTALL_DIR/bin:$INSTALL_DIR/sbin:\$PATH'" >> "$SHELL_RC"
    fi
    log_success "Environment configured in $SHELL_RC"
else
    log_info "Homebrew already configured in $SHELL_RC"
fi

# Export variables for current session
export HOMEBREW_PREFIX="$INSTALL_DIR"
export HOMEBREW_CELLAR="$INSTALL_DIR/Cellar"
export HOMEBREW_REPOSITORY="$INSTALL_DIR"
export PATH="$INSTALL_DIR/bin:$INSTALL_DIR/sbin:$PATH"

log_step "6. Configure Homebrew"
if [ "$USE_CHINA_MIRROR" = true ]; then
    log_info "Setting up China mirrors for Homebrew..."

    # Update git remotes for China mirrors
    cd "$INSTALL_DIR"

    # Update brew tap
    git config --local --replace-all homebrew.analyticsmessage false
    git config --local --replace-all homebrew.caskanalyticsmessage false

    # Change to Tsinghua Tuna mirror
    git remote set-url origin https://mirrors.tuna.tsinghua.edu.cn/git/homebrew/brew.git

    # Set up core tap mirror
    if [ -d "$INSTALL_DIR/Library/Taps/homebrew/homebrew-core" ]; then
        cd "$INSTALL_DIR/Library/Taps/homebrew/homebrew-core"
        git remote set-url origin https://mirrors.tuna.tsinghua.edu.cn/git/homebrew/homebrew-core.git
    else
        # Create core tap directory
        mkdir -p "$INSTALL_DIR/Library/Taps/homebrew"
        cd "$INSTALL_DIR/Library/Taps/homebrew"
        git clone https://mirrors.tuna.tsinghua.edu.cn/git/homebrew/homebrew-core.git
    fi

    # Set environment variables for bottle mirrors
    echo "" >> "$SHELL_RC"
    echo "# Homebrew China Mirrors" >> "$SHELL_RC"
    echo "export HOMEBREW_BOTTLE_DOMAIN=https://mirrors.tuna.tsinghua.edu.cn/homebrew-bottles" >> "$SHELL_RC"
    echo "export HOMEBREW_CORE_GIT_REMOTE=https://mirrors.tuna.tsinghua.edu.cn/git/homebrew/homebrew-core.git" >> "$SHELL_RC"
    echo "export HOMEBREW_BREW_GIT_REMOTE=https://mirrors.tuna.tsinghua.edu.cn/git/homebrew/brew.git" >> "$SHELL_RC"

    # Export for current session
    export HOMEBREW_BOTTLE_DOMAIN=https://mirrors.tuna.tsinghua.edu.cn/homebrew-bottles
    export HOMEBREW_CORE_GIT_REMOTE=https://mirrors.tuna.tsinghua.edu.cn/git/homebrew/homebrew-core.git
    export HOMEBREW_BREW_GIT_REMOTE=https://mirrors.tuna.tsinghua.edu.cn/git/homebrew/brew.git

    log_success "China mirrors configured"
fi

log_step "7. Install Core Tap"
log_info "Installing Homebrew core tap..."
"$INSTALL_DIR/bin/brew" update
"$INSTALL_DIR/bin/brew" analytics off
"$INSTALL_DIR/bin/brew" tap homebrew/core
if [ $? -eq 0 ]; then
    log_success "Core tap installed"
else
    log_warning "Core tap installation had issues, but continuing..."
fi

log_step "8. Verify Installation"
log_info "Checking Homebrew version..."
BREW_VERSION=$("$INSTALL_DIR/bin/brew" --version 2>/dev/null || echo "Unknown")
if [[ "$BREW_VERSION" != "Unknown" ]]; then
    log_success "Homebrew version: $(echo "$BREW_VERSION" | head -1)"
else
    log_error "Failed to get Homebrew version"
    exit 1
fi

log_info "Testing brew doctor..."
if "$INSTALL_DIR/bin/brew" doctor 2>&1 | grep -q "Your system is ready to brew"; then
    log_success "✓ Homebrew installation verified"
else
    log_warning "⚠ Homebrew doctor shows warnings (this is normal for fresh install)"
fi

log_step "9. Display Configuration Summary"

# 修复颜色显示问题 - 使用多个 echo 语句而不是 heredoc
echo ""
echo -e "${CYAN}╔══════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║                  Homebrew Installation Complete                  ║${NC}"
echo -e "${CYAN}╠══════════════════════════════════════════════════════════════════╣${NC}"
echo -e "${CYAN}║ Configuration Summary:                                           ║${NC}"
echo -e "${CYAN}║                                                                  ║${NC}"
echo -e "${CYAN}║  • Homebrew Version: $(printf '%-20s' "$(echo "$BREW_VERSION" | head -1)")${NC}"
echo -e "${CYAN}║  • Install Location: $INSTALL_DIR${NC}"
echo -e "${CYAN}║  • Current User: $USER${NC}"
echo -e "${CYAN}║  • Shell: $SHELL_NAME${NC}"

if [ "$USE_CHINA_MIRROR" = true ]; then
    echo -e "${CYAN}║  • Using China Mirror: ${GREEN}Yes${CYAN}                               ║${NC}"
else
    echo -e "${CYAN}║  • Using China Mirror: ${YELLOW}No${CYAN}                                ║${NC}"
fi

echo -e "${CYAN}║                                                                  ║${NC}"
if [ "$USE_CHINA_MIRROR" = true ]; then
    echo -e "${CYAN}║ China Mirror Configuration:                                    ║${NC}"
    echo -e "${CYAN}║  • Repo: Tsinghua Tuna mirror                               ║${NC}"
    echo -e "${CYAN}║  • Bottles: https://mirrors.tuna.tsinghua.edu.cn/homebrew-bottles ║${NC}"
fi
echo -e "${CYAN}║                                                                  ║${NC}"
echo -e "${CYAN}║ Important Next Steps:                                            ║${NC}"
echo -e "${CYAN}║  • Reload shell: ${YELLOW}source $SHELL_RC${CYAN}                    ║${NC}"
echo -e "${CYAN}║  • Or reopen terminal                                            ║${NC}"
echo -e "${CYAN}║  • Test: ${YELLOW}brew --version${CYAN}                                ║${NC}"
echo -e "${CYAN}║  • Update: ${YELLOW}brew update${CYAN}                                  ║${NC}"
echo -e "${CYAN}║  • Install package: ${YELLOW}brew install wget${CYAN}                     ║${NC}"
echo -e "${CYAN}║                                                                  ║${NC}"
echo -e "${CYAN}║ Need help? Run: ${YELLOW}brew help${CYAN}                                 ║${NC}"
echo -e "${CYAN}╚══════════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Final instructions
log_step "10. Final Steps"
echo ""
echo -e "${YELLOW}To start using Homebrew, run:${NC}"
echo "  source $SHELL_RC"
echo ""
echo -e "${YELLOW}Or restart your terminal${NC}"
echo ""
echo -e "${YELLOW}Test your installation:${NC}"
echo "  brew --version"
echo "  brew install hello"
echo "  hello"
echo ""
log_success "✅ Homebrew installation completed successfully!"