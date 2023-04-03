#!/bin/bash

# Author:  Persi.Liao <xiangchu.liao AT gmail.com>
#
# Notes: Linux Took Kit
#
# Project home page:
#    https://github.com/persiliao/ltk

cd "$(dirname "$0")" || {
  fmt_error "You do not have permission to do this."
  exit 1;
}

LTK_DIRECTORY="$(pwd)"

. "${LTK_DIRECTORY}/bootstrap.sh"

setup_install_vim() {
  if ! command_exists vim; then
    fmt_tips "Do you want to install vim? [Y/n] "
    read -r opt
    case $opt in
      y*|Y*|"") ;;
      *) fmt_notice "Invalid choice. vim install skipped."; return ;;
    esac

    is_redhat && yum install -y vim
    is_ubuntu && apt-get install -y vim

    fmt_information "Vim install successfully."
  fi
}

setup_vimrc() {
  if command_exists vim; then
    fmt_tips "Do you want to install .vimrc? [Y/n] "
    read -r opt
    case $opt in
      y*|Y*|"") ;;
      *) fmt_notice "Invalid choice. .vimrc install skipped."; return ;;
    esac

    if [ -f ~/.vimrc ]; then
      cp ~/.vimrc ~/.vimrc.backup.ltk
      fmt_notice "The original vimrc backup is in ~/.vimrc.backup.ltk"
    fi

    cp "${LTK_DIRECTORY}/conf/.vimrc" ~/.vimrc

    fmt_information "Vimrc install successfully."
  fi
}

main() {
  setup_install_vim
  setup_vimrc
}

main
