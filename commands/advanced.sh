#!/bin/zsh

ltk_lg() {
  ls | grep -v grep | grep -i "$1"
}

ltk_pg() {
  ps -ef | grep -v grep | grep -i "$1"
}

ltk_netsg() {
  netstat -an | grep -v grep | grep -i "$1"
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

ltk_http_clashx_proxy() {
  if ! netstat -an | grep -q -c 127.0.0.1.7890; then
    fmt_error "ClashX does not appear to be started."
    return 1
  fi
  export http_proxy=http://127.0.0.1:7890
  export https_proxy=http://127.0.0.1:7890
  export all_proxy=socks5://127.0.0.1:7890
  fmt_information "Setting the http proxy succeeded. 127.0.0.1:7890"
}

ltk_unset_http_proxy() {
  unset http_proxy
  unset https_proxy
  unset all_proxy
}

ltk_macos_enable_all_installation_sources() {
  if [ "$(uname)" != "Darwin" ]; then
    fmt_error "The current system is not macOS."
    return 1
  fi
  if sudo spctl --master-disable; then
    fmt_information "Setting the mac Allows installation of any source software successfully."
  fi
}

ltk_kill_by_port() {
  if [ -z $1 ]; then
    fmt_error "Please enter the port number."
    return 1
  fi
  $(lsof -i:$1 | awk '{print $2}' | tail -n 1| xargs kill -15)
}

ltk_show_all_listen() {
  lsof -i -P -n | grep LISTEN | awk '{print $1, $2, $3, $8, $9}' | sort -k 1 -n | column -t
}

ltk_show_ipv4() {
  if [[ "$(uname -s)" == "Linux" ]]; then
    ip -o -4 addr show | awk '{print $2, $4}' | grep -v 'lo' | sed 's/^\([^:]*\): /\1\t/' | sort -k 2 -n | column -t
  elif [[ "$(uname -s)" == "Darwin" ]]; then
    ifconfig | grep 'inet' | grep -v 'inet6' | grep -v '127.0.0.1' | awk '{print $1, $2}' | sed 's/:/ /' | sort -k 2 -n | column -t
  fi
}

alias lg=ltk_lg
alias pg=ltk_pg
alias nsg=ltk_netsg
alias tczero='truncate -s 0'
alias tczmail='truncate -s 0 /var/mail/${USER}'
alias showSystemVersion=ltk_system_version
alias showSystemReleaseVersion='lsb_release -a'
alias tf=ltk_tail
alias killByPort=ltk_kill_by_port
alias showPath='echo $PATH'
alias deleteAllSpace="sed -i '/^\s*$/d'"
alias lsdu='ls|xargs du -sh'
alias lsdusr='ls|xargs du -sh|sort -hr'
alias lsdusr10='ls|xargs du -sh|sort -hr|head -n 10'
alias lldu='ls -A|xargs du -sh'
alias lldusr='ls -A|xargs du -sh|sort -hr'
alias lldusr10='ls -A|xargs du -sh|sort -hr|head -n 10'
alias llipv4=ltk_show_ipv4
alias llListen=ltk_show_all_listen

# Proxy
alias setHttpV2rayProxy=ltk_http_v2ray_proxy
alias unsetHttpProxy=ltk_unset_http_proxy
alias setHttpClashXProxy=ltk_http_clashx_proxy

# Mac
alias macAppInstallSourceAll=ltk_macos_enable_all_installation_sources
