ltk_ubuntu_set_apt_mirror() {
  if [ ! -s '/etc/apt/sources.list' ]; then
    fmt_error "Current OS system not a ubuntu."
    return 1
  fi

  fmt_tips "Do you want to set apt mirror? [Y/n] "
  read -r opt
  case $opt in
  y*|Y*|"") ;;
  n*|N*) fmt_notice "Set apt mirror skipped."; return ;;
  *) fmt_notice "Invalid choice. Set apt mirror skipped."; return ;;
  esac

  printf 'Which mirror do you want to set?
    %st%s. mirrors.cloud.tencent.com
    %sa%s. mirrors.aliyun.com \n' \
    "${FMT_YELLOW}" "${FMT_RESET}" "${FMT_YELLOW}" "${FMT_RESET}"
  fmt_tips "Please input the correct option: "
  read -r opt
  case $opt in
    t*|T*) sed -i s/archive.ubuntu.com/mirrors.aliyun.com/g /etc/apt/sources.list ;;
    a*|A*) sed -i s/archive.ubuntu.com/mirrors.cloud.tencent.com/g /etc/apt/sources.list ;;
    *) fmt_notice "Invalid choice. Set apt mirror skipped."; return ;;
  esac

  fmt_information "apt mirror set successfully, Now let's start updating"

  apt clean all
  apt update
}

ltk_npm_set_registry() {
  if ! command_exists npm ; then
    fmt_error "Please install the node & npm first."
    return 1
  fi

  fmt_tips "Do you want to set npm registry? [Y/n] "
  read -r opt
  case $opt in
  y*|Y*|"") ;;
  n*|N*) fmt_notice "Set npm registry skipped."; return ;;
  *) fmt_notice "Invalid choice. Set npm registry skipped."; return ;;
  esac

  printf 'Which registry do you want to set?
    %sq%s. https://mirrors.cloud.tencent.com/npm
    %st%s. https://registry.npm.taobao.org \n' \
    "${FMT_YELLOW}" "${FMT_RESET}" "${FMT_YELLOW}" "${FMT_RESET}"
  fmt_tips "Please input the correct option: "
  read -r opt
  case $opt in
    t*|T*) npm config set registry https://registry.npm.taobao.org/ ;;
    q*|Q*) npm config set registry https://mirrors.cloud.tencent.com/npm/ ;;
    *) fmt_notice "Invalid choice. Set npm registry skipped."; return ;;
  esac

  fmt_information "npm registry set successfully."
}

ltk_drone_check_server() {
  if ! command_exists drone; then
    fmt_error "Please install the drone cli first."
    exit 1
  fi
  if [ -z "${DRONE_SERVER}" ] || [ -z "${DRONE_TOKEN}" ]; then
    fmt_error "You must provide the Drone server address. export DRONE_SERVER, DRONE_TOKEN"
    exit 1
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
  y*|Y*|"") ;;
  n*|N*) fmt_notice "Drone sign skipped."; return ;;
  *) fmt_notice "Invalid choice. Drone sign skipped."; return ;;
  esac

  if drone sign --save "${LTK_GIT_REPO_NAME}" "${LTK_DRONE_REPO_CONFIG}"; then
    fmt_information "Drone sign successfully."
  fi
}

# Acme.sh
ltk_acme_renew_ssl() {
  if ! command_exists acme.sh; then
      fmt_error "Please install the acme.sh first."
      exit 1
  fi

  if [ ! -f "${HOME}/.acme.sh/acme.sh" ]; then
    fmt_error "Please install the acme.sh first."
    exit 1
  fi

  if [ -z "${1}" ]; then
    fmt_error "Please enter the domain name for which you want the certificate."
    exit 1
  fi

  "${HOME}"/.acme.sh/acme.sh --renew -d "${1}"
}

alias ubuntuSetAptMirror=ltk_ubuntu_set_apt_mirror
alias npmSetRegistry=ltk_npm_set_registry
alias npmUnsetRegistry='npm config delete registry'
alias npmGetRegistry='npm config get registry'
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
    git remote -v|grep push|awk '{print $1}'|xargs -t -n 1 git push
}

# Git
alias gtdall='git tag |xargs git tag -d'
alias gct='git checkout test'
alias gmt='git merge test'
alias gmm='git merge master'
alias gmd='git merge develop'
alias ggpushmaster='git push origin $(git_main_branch)'
alias gsa='git submodule add'
alias gsui='git submodule update --init --recursive'
alias gsurm='git submodule update --recursive --remote --merge'
alias ggplsurm='git pull origin $(git_main_branch) && git submodule update --recursive --remote --merge'
alias gcmsg='ltk_gcmsg'
alias gcmsgd='ltk_gacmsgd'
alias gcmsgcp='ltk_gcmsgcp'
alias gacmsg='ltk_gacmsg'
alias gacmsgcp='ltk_gacmsgcp'
alias gacsp='ltk_gacsp'
alias gacp='ltk_gacp'
alias ggpushall='ltk_gitPushAll'

# Java Maven
alias mvndcpst='mvnd clean package -DskipTests'
