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
  exit 1
fi

setup_sudoer_add_user() {
  fmt_tips "Do you want to add a user to sudoers? [Y/n] "
  read -r opt

  case $opt in
    y*|Y*|"") ;;  # Do nothing, continue.
    n*|N*) fmt_notice "Add user to sudoers skipped."; return ;;
    *) fmt_notice "Invalid choice. Add user to sudoers skipped."; return ;;
  esac

  while :; do
    fmt_tips "Please enter the username you want to add to sudoers: "
    read -r LTK_SUDOER_USER

    if [ -z "${LTK_SUDOER_USER}" ]; then
      fmt_error "Username cannot be empty."
      continue
    fi

    if ! id "${LTK_SUDOER_USER}" &>/dev/null; then
      fmt_error "User ${LTK_SUDOER_USER} does not exist."
      continue
    fi

    if grep -q "^${LTK_SUDOER_USER} ALL=" /etc/sudoers; then
      fmt_notice "User ${LTK_SUDOER_USER} is already in sudoers."
      return
    fi

    echo "${LTK_SUDOER_USER} ALL=(ALL) NOPASSWD: ALL" | sudo tee -a /etc/sudoers > /dev/null
    fmt_information "Added user ${LTK_SUDOER_USER} to sudoers successfully."
    break
  done
}

main() {
  setup_sudoer_add_user
}

main
