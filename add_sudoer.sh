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

# Check if user is root
if ! is_root; then
  fmt_error "You must be ${FMT_GREEN}root${FMT_RESET} ${FMT_RED}to run this script.";
  exit 1;
fi

setup_sudoer_add_user() {
  fmt_tips "Do you want to add user to sudoers? [Y/n] "
  read -r opt
  case $opt in
    y*|Y*|"") ;;
    n*|N*) fmt_notice "add user to sudoers skipped."; return ;;
    *) fmt_notice "Invalid choice. add user to sudoers skipped."; return ;;
  esac

  while :; do
    fmt_tips "Please enter what you want to add to sudoers "
    read -r LTK_SUDOER_USER
    if [ "${LTK_SUDOER_USER}" != "" ] && grep -q -c "^${LTK_SUDOER_USER}" /etc/passwd; then
      break
    fi
  done

  if echo "${LTK_SUDOER_USER} ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers; then
    fmt_information "Add user ${LTK_SUDOER_USER} to sudoers successfully."
  fi
}

main() {
  setup_sudoer_add_user
}

main
