#!/bin/bash

# Author:  Persi.Liao <xiangchu.liao AT gmail.com>
#
# Notes: Linux Took Kit
#
# Project home page:
#    https://github.com/persiliao/ltk

cd "$(dirname "$0")" || {
  fmt_error "You do not have permission to do this."
  exit 1
}

LTK_DIRECTORY="$(pwd)"

. "${LTK_DIRECTORY}/bootstrap.sh"

# Check if user is root
if ! is_root; then
  fmt_error "You must be ${FMT_GREEN}root${FMT_RESET} ${FMT_RED}to run this script."
  exit 1;
fi

setup_install_docker() {
  fmt_tips "Do you want to install Docker? [Y/n] "
  read -r opt
  case $opt in
    y*|Y*|"") LTK_OPT_INSTALL_DOCKER=1;;
    n*|N*) fmt_notice "install Docker skipped."; return ;;
    *) fmt_notice "Invalid choice. install Docker skipped."; return ;;
  esac

  yum remove -y docker docker-client docker-client-latest docker-common docker-latest docker-latest-logrotate docker-logrotate docker-engine
  yum install -y yum-utils device-mapper-persistent-data lvm2
  yum-config-manager --add-repo https://mirrors.aliyun.com/docker-ce/linux/centos/docker-ce.repo
  yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
  yum-config-manager --enable docker-ce-nightly
  yum update -y
  yum makecache

  if yum install -y docker-ce docker-ce-cli containerd.io; then
    fmt_information "Docker install successfully."
  fi
}

setup_systemctl_service_restart() {
  if [ ${LTK_OPT_INSTALL_DOCKER} -eq 1 ]; then
    systemctl enable docker.service
    systemd_service_restart "docker.service"
  fi
}

main() {
  if ! check_in_docker; then
    setup_install_docker
    setup_systemctl_service_restart
  fi
}

main "$@"
