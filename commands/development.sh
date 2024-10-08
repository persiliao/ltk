#!/bin/zsh

ltk_ubuntu_set_apt_mirror() {
  if [ ! -s '/etc/apt/sources.list' ]; then
    fmt_error "Current OS system not a ubuntu."
    return 1
  fi

  fmt_tips "Do you want to set apt mirror? [Y/n] "
  read -r opt
  case $opt in
  y* | Y* | "") ;;
  n* | N*)
    fmt_notice "Set apt mirror skipped."
    return 1
    ;;
  *)
    fmt_notice "Invalid choice. Set apt mirror skipped."
    return 1
    ;;
  esac

  printf 'Which mirror do you want to set?
    %st%s. mirrors.cloud.tencent.com
    %sa%s. mirrors.aliyun.com \n' \
    "${FMT_YELLOW}" "${FMT_RESET}" "${FMT_YELLOW}" "${FMT_RESET}"
  fmt_tips "Please input the correct option: "
  read -r opt
  case $opt in
  t* | T*) sed -i s/archive.ubuntu.com/mirrors.aliyun.com/g /etc/apt/sources.list ;;
  a* | A*) sed -i s/archive.ubuntu.com/mirrors.cloud.tencent.com/g /etc/apt/sources.list ;;
  *)
    fmt_notice "Invalid choice. Set apt mirror skipped."
    return
    ;;
  esac

  fmt_information "apt mirror set successfully, Now let's start updating"

  apt clean all
  apt update
}

ltk_npm_set_registry() {
  if ! command_exists npm; then
    fmt_error "Please install the node & npm first."
    return 1
  fi

  fmt_tips "Do you want to set npm registry? [Y/n] "
  read -r opt
  case $opt in
  y* | Y* | "") ;;
  n* | N*)
    fmt_notice "Set npm registry skipped."
    return 1
    ;;
  *)
    fmt_notice "Invalid choice. Set npm registry skipped."
    return 1
    ;;
  esac

  printf 'Which registry do you want to set?
    %sqq%s. https://mirrors.cloud.tencent.com/npm
    %saliyun%s. https://registry.npmmirror.com \n' \
    "${FMT_YELLOW}" "${FMT_RESET}" "${FMT_YELLOW}" "${FMT_RESET}"
  fmt_tips "Please input the correct option: "
  read -r opt
  case $opt in
  t* | aliyun*) npm config set registry https://registry.npmmirror.com/ ;;
  q* | qq*) npm config set registry https://mirrors.cloud.tencent.com/npm/ ;;
  *)
    fmt_notice "Invalid choice. Set npm registry skipped."
    return 1
    ;;
  esac

  fmt_information "npm registry set successfully."
}

ltk_composer_set_registry() {
  if ! command_exists composer; then
    fmt_error "Please install the php & composer first."
    return 1
  fi

  fmt_tips "Do you want to set composer registry? [Y/n] "
  read -r opt
  case $opt in
  y* | Y* | "") ;;
  n* | N*)
    fmt_notice "Set composer registry skipped."
    return 1
    ;;
  *)
    fmt_notice "Invalid choice. Set composer registry skipped."
    return 1
    ;;
  esac

  printf 'Which registry do you want to set?
    %sq%s. https://mirrors.tencent.com/composer/
    %st%s. https://mirrors.aliyun.com/composer/ \n' \
    "${FMT_YELLOW}" "${FMT_RESET}" "${FMT_YELLOW}" "${FMT_RESET}"
  fmt_tips "Please input the correct option: "
  read -r opt
  case $opt in
  t* | T*) composer config -g repos.packagist composer https://mirrors.aliyun.com/composer/ ;;
  q* | Q*) composer config -g repos.packagist composer https://mirrors.tencent.com/composer/ ;;
  *)
    fmt_notice "Invalid choice. Set composer registry skipped."
    return 1
    ;;
  esac

  fmt_information "composer registry set successfully."
}

ltk_drone_check_server() {
  if ! command_exists drone; then
    fmt_error "Please install the drone cli first."
    return 1
  fi
  if [ -z "${DRONE_SERVER}" ] || [ -z "${DRONE_TOKEN}" ]; then
    fmt_error "You must provide the Drone server address. export DRONE_SERVER, DRONE_TOKEN"
    return 1
  fi
  return 0
}

ltk_drone_sign_repository() {
  ltk_drone_check_server
  LTK_GIT_REPO_NAME=$(ltk_get_git_remote_repo_name)
  LTK_DRONE_REPO_CONFIG=$(drone repo info "${LTK_GIT_REPO_NAME}" | grep Config | awk '{print $2}')
  if [ -z "${LTK_DRONE_REPO_CONFIG}" ]; then
    LTK_DRONE_REPO_CONFIG='.drone.yml'
  fi

  fmt_tips "Do you want to sign the current repository?[Y/n] "
  read -r opt
  case $opt in
  y* | Y* | "") ;;
  n* | N*)
    fmt_notice "Drone sign skipped."
    return 1
    ;;
  *)
    fmt_notice "Invalid choice. Drone sign skipped."
    return 1
    ;;
  esac

  if drone sign --save "${LTK_GIT_REPO_NAME}" "${LTK_DRONE_REPO_CONFIG}"; then
    fmt_information "Drone sign successfully."
  fi
}

# Acme.sh
ltk_acme_renew_ssl() {
  if ! command_exists acme.sh; then
    fmt_error "Please install the acme.sh first."
    return 1
  fi

  if [ ! -f "${HOME}/.acme.sh/acme.sh" ]; then
    fmt_error "Please install the acme.sh first."
    return 1
  fi

  if [ -z "${1}" ]; then
    fmt_error "Please enter the domain name for which you want the certificate."
    return 1
  fi

  "${HOME}"/.acme.sh/acme.sh --renew -d "${1}"
}

alias ubuntuSetAptMirror=ltk_ubuntu_set_apt_mirror

# Node
alias npmSetRegistry=ltk_npm_set_registry
alias npmUnsetRegistry='npm config delete registry'
alias npmGetRegistry='npm config get registry'
alias pnpmSetAutoInstallPeers='pnpm config set auto-install-peers true'

# Composer registry
alias composerSetRegistry=ltk_composer_set_registry
alias composerUnsetRegistry='composer config -g --unset repos.packagist'
alias composerShowRegistry='composer config -g -l |grep repositories'

# Python
alias pipUpgradeSelf='pip install --upgrade pip'

# CI/CD
alias droneSignRepository=ltk_drone_sign_repository

# Xdebug open cli listen
alias xdebugOpen='export XDEBUG_TRIGGER=true'
alias xdebugClose='unset XDEBUG_TRIGGER'

# Systemd
alias sc-logs='journalctl -f -u'

# Acme.sh
alias acmeRenew=ltk_acme_renew_ssl

# Git
ltk_gacsp() {
  local message=$1
  if [[ -z ${message} ]]; then
    fmt_error "Aborting commit due to empty commit message"
    return
  fi
  local branch=$(git_current_branch)
  git add . && git commit -m "${*}" && git pull origin "${branch}" && git submodule update --recursive --remote --merge && git add . && git commit -m "${*}" && git push origin "${branch}"
}

ltk_gacp() {
  local message=$1
  if [ -z "${message}" ]; then
    fmt_error "Aborting commit due to empty commit message"
    return
  fi
  branch=$(git_current_branch)
  git add . && git commit -m "${*}" && git pull origin "${branch}" && git push origin "${branch}"
}

ltk_gacmsg() {
  local message=$1
  if [ -z "${message}" ]; then
    fmt_error "Aborting commit due to empty commit message"
    return
  fi
  git add . && git commit -m "${*}"
}

ltk_gacmsgcp() {
  git add . && git commit -m "refactor: Code optimization"
}

ltk_gcmsg() {
  local message=$1
  if [ -z "${message}" ]; then
    fmt_error "Aborting commit due to empty commit message"
    return
  fi
  git commit -m "${*}"
}

ltk_gacmsgd() {
  local message=$1
  if [ -z "${message}" ]; then
    fmt_error "Aborting commit due to empty commit message"
    return
  fi
  git commit --amend -m "${*}"
}

ltk_gcmsgcp() {
  git commit -m "refactor: Code optimization"
}

ltk_gitPushAll() {
  git remote -v | grep push | awk '{print $1}' | xargs -t -n 1 git push
}

ltk_touch_gitignore() {
  local TEMPLATENAME=$1
  if [ -z "${TEMPLATENAME}" ]; then
    touch .gitignore
  else
    gi "${TEMPLATENAME}" >>.gitignore
  fi
}

# Git
alias gtdall='git tag |xargs git tag -d'
alias gcld1='git clone --depth=1 '
alias gct='git checkout test'
alias gmt='git merge test'
alias gmm='git merge master'
alias gmd='git merge develop'
alias ggpushmaster='git push origin $(git_main_branch)'
alias gsa='git submodule add'
alias gsui='git submodule update --init --recursive'
alias gsurm='git submodule update --recursive --remote --merge'
alias ggplsurm='git pull origin $(git_main_branch) && git submodule update --recursive --remote --merge'
alias gcmdp='gcm && gmd && ggpush && gcd'
alias gcmsg='ltk_gcmsg'
alias gcmsgd='ltk_gacmsgd'
alias gcmsgcp='ltk_gcmsgcp'
alias gacmsg='ltk_gacmsg'
alias gacmsgcp='ltk_gacmsgcp'
alias gacmsgpush='gacmsgcp && ggpush'
alias gacsp='ltk_gacsp'
alias gacp='ltk_gacp'
alias ggpushall='ltk_gitPushAll'
alias grao='git remote add origin'
alias grrmo='git remote remove origin'
alias gSetTrace='export GIT_TRACE=1'
alias gUnsetTrace='unset GIT_TRACE'
alias ginew=ltk_touch_gitignore

# Java Maven
alias mvncpst='mvn clean package -DskipTests'
alias mvndcpst='mvnd clean package -DskipTests'

# Rust
alias rustOpenFullBacktrace='export RUST_BACKTRACE=full'
alias rustCloseFullBacktrace='unset RUST_BACKTRACE'

# Gpg
export GPG_TTY=$(tty)
alias gpgRestart='gpgconf --kill gpg-agent'
