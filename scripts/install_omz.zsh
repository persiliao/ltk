#!/bin/bash
# install_ohmyzsh.sh
# One-click oh-my-zsh installation
# Usage: bash install_ohmyzsh.sh

set -e  # Exit immediately on error

# Color definitions
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if command exists
check_command() {
    if ! command -v $1 &> /dev/null; then
        echo -e "${RED}Error: Command '$1' not found. Please install $1 first${NC}"
        exit 1
    fi
}

# Installation status messages
echo_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

echo_info() {
    echo -e "${YELLOW}ℹ $1${NC}"
}

echo_error() {
    echo -e "${RED}✗ $1${NC}"
}

# Main installation function
install_ohmyzsh() {
    echo_info "Starting oh-my-zsh installation..."

    # Check dependencies
    echo_info "Checking system dependencies..."
    check_command "zsh"
    check_command "git"
    check_command "curl"

    # Check if oh-my-zsh is already installed
    if [ -d "$HOME/.oh-my-zsh" ]; then
        echo_info "Existing oh-my-zsh installation detected"
        read -p "Reinstall? (y/N): " reinstall
        if [[ ! "$reinstall" =~ ^[Yy]$ ]]; then
            echo_info "Skipping installation"
            return
        fi
        echo_info "Backing up old installation to ~/.oh-my-zsh.backup-$(date +%Y%m%d%H%M%S)"
        mv "$HOME/.oh-my-zsh" "$HOME/.oh-my-zsh.backup-$(date +%Y%m%d%H%M%S)"
    fi

    # Backup existing .zshrc
    if [ -f "$HOME/.zshrc" ]; then
        backup_file="$HOME/.zshrc.backup-$(date +%Y%m%d%H%M%S)"
        echo_info "Backing up existing .zshrc to $backup_file"
        cp "$HOME/.zshrc" "$backup_file"
    fi

    # Install oh-my-zsh
    echo_info "Downloading oh-my-zsh..."
    if [ -n "$http_proxy" ] || [ -n "$https_proxy" ]; then
        echo_info "Proxy detected, installing via proxy..."
    fi

    # Use official installation script
    sh -c "$(curl -fsSL https://install.ohmyz.sh/)"

    if [ $? -eq 0 ]; then
        echo_success "oh-my-zsh installed successfully!"

        # Check if zsh is default shell
        if [ "$SHELL" != "$(which zsh)" ]; then
            echo_info "Current shell: $SHELL"
            echo_info "Recommend setting zsh as default: chsh -s $(which zsh)"
            read -p "Set zsh as default shell now? (Y/n): " change_shell
            if [[ ! "$change_shell" =~ ^[Nn]$ ]]; then
                chsh -s $(which zsh)
                echo_success "Zsh set as default shell. Re-login to apply"
            fi
        fi

        # Show post-installation tips
        echo ""
        echo_info "Installation complete! Recommended next steps:"
        echo_info "1. Edit ~/.zshrc for custom configuration"
        echo_info "2. View available themes: ls ~/.oh-my-zsh/themes"
        echo_info "3. View available plugins: ls ~/.oh-my-zsh/plugins"
        echo_info "4. Enable plugins: Edit plugins=() in ~/.zshrc"
        echo_info "5. Apply changes: source ~/.zshrc"

    else
        echo_error "Installation failed. Check network connection"
        echo_info "Try manual installation:"
        echo_info "git clone https://github.com/ohmyzsh/ohmyzsh.git ~/.oh-my-zsh"
        echo_info "cp ~/.oh-my-zsh/templates/zshrc.zsh-template ~/.zshrc"
        exit 1
    fi
}

# Execute installation
main() {
    echo_info "=== oh-my-zsh One-Click Installer ==="
    echo_info "System: $(uname -s)"
    echo_info "User: $(whoami)"
    echo_info "Time: $(date)"
    echo ""

    read -p "Continue installation? (Y/n): " confirm
    if [[ "$confirm" =~ ^[Nn]$ ]]; then
        echo_info "Installation cancelled"
        exit 0
    fi

    install_ohmyzsh
}

# Execute main function
main "$@"
