ltk_lg() {
  # shellcheck disable=SC2010
  ls | grep -i "$1"
}

ltk_pg() {
  # shellcheck disable=SC2009
  ps -ef | grep -i "$1"
}

ltk_netsg() {
  netstat -an | grep -i "$1"
}

ltk_system_version() {
  if [ -f "/etc/redhat-release" ]; then
    cat /etc/redhat-release
  elif [ -f "/etc/issue" ]; then
    cat /etc/issue
  else
    uname -a
  fi
}

ltk_tail() {
  if [ ! -f "$1" ]; then
    fmt_error "File ${1} does not exists"
    return 1
  fi
  lines=$2
  if [ -n "${lines}" ]; then
    lines=100
  fi
  tail -n "${lines}" -F "$1"
}

ltk_http_v2ray_proxy() {
  if ! netstat -an | grep -q -c 127.0.0.1.1087; then
    fmt_error "v2ray does not appear to be started."
    return 1
  fi
  export http_proxy=http://127.0.0.1:1087
  export https_proxy=http://127.0.0.1:1087
  fmt_information "Setting the http proxy succeeded. 127.0.0.1:1087"
}

ltk_unset_http_proxy() {
  unset http_proxy
  unset https_proxy
}

ltk_macos_enable_all_installation_sources() {
  if [ "$(uname)" != "Darwin" ]; then
    fmt_error "The current system is not macOS."
    exit 1
  fi
  if sudo spctl --master-disable; then
    fmt_information "Setting the mac Allows installation of any source software successfully."
  fi
}

ltk_kill_by_port() {
  if [ -z $1 ]; then
    fmt_error "Please enter the port number."
    exit 1
  fi
  $(lsof -i:$1 | awk '{print $2}' | tail -n 1 | xargs kill -9)
}

alias lg=ltk_lg
alias pg=ltk_pg
alias nsg=ltk_netsg
alias tczero='truncate -s 0'
alias mailtcz='truncate -s 0 /var/mail/${USER}'
alias showSystemVersion=ltk_system_version
alias tf=ltk_tail
alias killByPort=ltk_kill_by_port
alias showPath='echo $PATH'
alias deleteAllSpace="sed -i '/^\s*$/d'"

# Proxy
alias setHttpV2rayProxy=ltk_http_v2ray_proxy
alias unsetHttpProxy=ltk_unset_http_proxy

# Mac
alias macAppInstallSourceAll=ltk_macos_enable_all_installation_sources
