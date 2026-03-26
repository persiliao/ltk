#!/usr/bin/env zsh
# Oh My Zsh Plugin Setup - Optimized English Version
# Enhanced structure, error handling, and readability

# --------------------------
# Color & Icon Definitions
# --------------------------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

ICON_INFO="ℹ️"
ICON_SUCCESS="✅"
ICON_WARNING="⚠️"
ICON_ERROR="❌"
ICON_LINUX="🐧"
ICON_MAC="🍎"
ICON_DOCKER="🐳"
ICON_K8S="☸️"
ICON_WEB="🌐"
ICON_PYTHON="🐍"
ICON_DB="🗃️"
ICON_RELOAD="🔁"
ICON_OMZ="✨"
ICON_INSTALL="📥"

# --------------------------
# Print Helper Functions
# --------------------------
print_info()    { echo -e "${BLUE}${ICON_INFO} $1${NC}"; }
print_success() { echo -e "${GREEN}${ICON_SUCCESS} $1${NC}"; }
print_warning() { echo -e "${YELLOW}${ICON_WARNING} $1${NC}"; }
print_error()   { echo -e "${RED}${ICON_ERROR} $1${NC}"; }
print_section() { echo -e "${PURPLE}$1${NC}"; }
print_command() { echo -e "${CYAN}$1${NC}"; }
print_install() { echo -e "${GREEN}${ICON_INSTALL} $1${NC}"; }

# --------------------------
# Core Utility Functions
# --------------------------
get_omz_path() {
  [[ -f "$HOME/.oh-my-zsh/oh-my-zsh.sh" ]] && echo "$HOME/.oh-my-zsh" || echo ""
}

is_plugin_installed() {
  local plugin="$1"
  local omz=$(get_omz_path)
  [[ -d "${omz}/plugins/${plugin}" || -d "${omz}/custom/plugins/${plugin}" ]]
}

# --------------------------
# Auto-install Missing Plugins
# --------------------------
auto_install_missing_plugins() {
  print_info "Checking and installing missing plugins..."
  local omz=$(get_omz_path)
  local custom_dir="${omz}/custom/plugins"
  mkdir -p "${custom_dir}"

  declare -A repos=(
    ["zsh-syntax-highlighting"]="https://github.com/zsh-users/zsh-syntax-highlighting.git"
    ["zsh-autosuggestions"]="https://github.com/zsh-users/zsh-autosuggestions.git"
    ["history-substring-search"]="https://github.com/zsh-users/zsh-history-substring-search.git"
    ["kubectx"]="https://github.com/ahmetb/kubectx.git"
    ["kube-ps1"]="https://github.com/jonmosco/kube-ps1.git"
    ["terraform"]="https://github.com/ohmyzsh/terraform-plugin.git"
    ["ansible"]="https://github.com/ohmyzsh/ansible-plugin.git"
  )

  local count=0
  for plugin url in ${(kv)repos}; do
    if ! is_plugin_installed "${plugin}"; then
      print_install "Installing plugin: ${plugin}"
      git clone --depth=1 "${url}" "${custom_dir}/${plugin}" >/dev/null 2>&1
      ((count++))
    fi
  done

  (( count > 0 )) && print_success "Installed ${count} plugins" || print_success "All plugins already exist"
}

# --------------------------
# OMZ Command Wrapper
# --------------------------
run_omz_command() {
  local cmd="$1"
  shift
  local args=("$@")

  if command -v omz &>/dev/null; then
    omz ${cmd} "${args[@]}"
    return $?
  fi

  local omz=$(get_omz_path)
  [[ -z "${omz}" ]] && { print_error "Oh My Zsh not found"; return 1; }

  case "${cmd}" in
    plugin)
      [[ "$1" == enable ]] && { shift; enable_plugins_directly "$@"; } ;;
    reload)
      print_warning "Please run manually: omz reload" ;;
    *)
      print_error "Unsupported command: ${cmd}" ;;
  esac
}

# --------------------------
# Direct .zshrc Plugin Enable
# --------------------------
enable_plugins_directly() {
  local plugins=("$@")
  [[ ${#plugins[@]} -eq 0 ]] && { print_error "No plugins specified"; return 1; }

  local zshrc="$HOME/.zshrc"
  [[ ! -f "${zshrc}" ]] && { print_error "${zshrc} not found"; return 1; }

  local current=()
  if grep -q "^plugins=" "${zshrc}"; then
    current=("${(@s/ /)$(grep "^plugins=" "${zshrc}" | sed 's/plugins=(//;s/)//')}")
  fi

  for p in "${plugins[@]}"; do
    [[ ! " ${current[@]} " =~ " ${p} " ]] && current+=("${p}")
  done

  local new_line="plugins=(${current[@]})"
  if grep -q "^plugins=" "${zshrc}"; then
    [[ $(uname) == Darwin ]] && sed -i '' "s|^plugins=.*|${new_line}|" "${zshrc}" \
                               || sed -i "s|^plugins=.*|${new_line}|" "${zshrc}"
  else
    echo "${new_line}" >> "${zshrc}"
  fi

  print_success "Updated .zshrc plugin list"
}

# --------------------------
# Pre-flight Check
# --------------------------
check_omz_installed() {
  if [[ ! -d "$HOME/.oh-my-zsh" || ! -f "$HOME/.zshrc" ]]; then
    print_error "Oh My Zsh is not installed"
    print_command "sh -c \"\$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)\""
    exit 1
  fi
}

# --------------------------
# Plugin Configuration Sets
# --------------------------
configure_plugins() {
  local cfg="$1"
  case "${cfg}" in
    enable-all)
      local plat=()
      [[ $(uname) == Darwin ]] && plat=(brew macos) || plat=(systemd)
      local common=(sudo dotenv wd tmux systemadmin gpg-agent git git-flow git-extras gitfast gh isodate ssh-agent git-commit docker docker-compose zsh-syntax-highlighting zsh-autosuggestions history-substring-search)
      run_omz_command plugin enable ${plat[@]} ${common[@]}
      print_success "Full suite enabled" ;;

    basic)
      local set=(git sudo dotenv wd tmux ssh-agent zsh-syntax-highlighting zsh-autosuggestions)
      run_omz_command plugin enable ${set[@]}
      print_success "Basic plugins enabled" ;;

    docker)
      local set=(git sudo dotenv wd tmux docker docker-compose docker-machine zsh-syntax-highlighting zsh-autosuggestions)
      [[ $(uname) != Darwin ]] && set+=(systemd)
      run_omz_command plugin enable ${set[@]}
      echo -e "${GREEN}${ICON_DOCKER} Docker plugins enabled${NC}" ;;

    k8s)
      local set=(git sudo dotenv kubectl kubectx helm kube-ps1 wd tmux docker zsh-syntax-highlighting zsh-autosuggestions)
      run_omz_command plugin enable ${set[@]}
      echo -e "${GREEN}${ICON_K8S} Kubernetes plugins enabled${NC}" ;;

    linux)
      [[ $(uname) != Linux ]] && print_warning "Current system is not Linux"
      local set=(git sudo dotenv systemadmin systemd history screen ssh-agent wd tmux zsh-syntax-highlighting zsh-autosuggestions)
      run_omz_command plugin enable ${set[@]}
      echo -e "${GREEN}${ICON_LINUX} Linux plugins enabled${NC}" ;;

    devops)
      local set=(git sudo dotenv docker docker-compose kubectl helm terraform ansible wd tmux zsh-syntax-highlighting zsh-autosuggestions)
      run_omz_command plugin enable ${set[@]}
      print_success "DevOps plugins enabled" ;;

    remote)
      local set=(git sudo dotenv ssh-agent rsync screen tmux wd history-substring-search zsh-syntax-highlighting zsh-autosuggestions)
      run_omz_command plugin enable ${set[@]}
      print_success "Remote admin plugins enabled" ;;

    web-dev)
      local set=(git sudo dotenv node npm yarn nvm wd tmux docker docker-compose zsh-syntax-highlighting zsh-autosuggestions)
      run_omz_command plugin enable ${set[@]}
      echo -e "${GREEN}${ICON_WEB} Web dev plugins enabled${NC}" ;;

    python-dev)
      local set=(git sudo dotenv python pip pyenv virtualenv wd tmux docker zsh-syntax-highlighting zsh-autosuggestions)
      run_omz_command plugin enable ${set[@]}
      echo -e "${GREEN}${ICON_PYTHON} Python dev plugins enabled${NC}" ;;

    db-admin)
      local set=(git sudo dotenv wd tmux redis-cli postgresql mysql mariadb zsh-syntax-highlighting zsh-autosuggestions)
      run_omz_command plugin enable ${set[@]}
      echo -e "${GREEN}${ICON_DB} Database plugins enabled${NC}" ;;

    *)
      echo -e "${PURPLE}${ICON_OMZ} Oh My Zsh Plugin Manager ${ICON_OMZ}${NC}"
      echo -e "${PURPLE}====================================================${NC}"
      echo ""
      print_section "Available Configurations:"
      echo "  enable-all    Full plugin suite"
      echo "  basic         Basic essential plugins"
      echo "  docker        Docker & containers"
      echo "  k8s           Kubernetes tools"
      echo "  linux         Linux server admin"
      echo "  devops        DevOps toolchain"
      echo "  remote        Remote server management"
      echo "  web-dev       Web development"
      echo "  python-dev    Python development"
      echo "  db-admin      Database administration"
      echo ""
      print_command "Usage: ./omz_plugin_setup.zsh docker"
      print_command "Activate: omz reload"
      exit 0 ;;
  esac
}

# --------------------------
# Main Entry Point
# --------------------------
main() {
  check_omz_installed
  auto_install_missing_plugins
  configure_plugins "$1"
  [[ -n "$1" ]] && echo -e "\n${YELLOW}${ICON_RELOAD} Run omz reload to apply changes${NC}\n"
}

main "$@"