#!/bin/bash

# Author:  Persi.Liao <xiangchu.liao AT gmail.com>
#
# Notes: Linux Took Kit
#
# Project home page:
#    https://github.com/persiliao/ltk

cd "$(dirname "$0")" || {
  fmt_error "You must be ${FMT_GREEN}root${FMT_RESET} ${FMT_RED}to run this script.";
  exit 1;
}

LTK_DIRECTORY="$(pwd)"

. "${LTK_DIRECTORY}/include/bootstrap.sh"

setup_optimize_git_config() {
  if ! command_exists git; then
    fmt_error "You haven't installed git yet."
    exit 1
  fi

  fmt_tips "You want to start setting up your git configuration? [Y/n] "
  read -r opt
  case $opt in
    y*|Y*|"") ;;
    *) fmt_notice "Invalid choice. setting git configuration skipped."; return ;;
  esac

  if ! git config --global --get user.name > /dev/null; then
    while :; do
      fmt_tips "Please enter the name used for git commit. (e: git@git.com): "
      read -r LTK_GIT_USER_NAME
      if [ "${LTK_GIT_USER_NAME}" != "" ]; then
        break
      else
        fmt_error "Invalid name."
      fi
    done
  fi

  if ! git config --global --get user.email > /dev/null; then
    while :; do
      fmt_tips "Please enter the email address used for git commit. (e: git@git.com): "
      read -r LTK_GIT_USER_EMAIL
      if validate_email "${LTK_GIT_USER_EMAIL}"; then
        break
      else
        fmt_error "Invalid email address."
      fi
    done
  fi

  fmt_notice "Begin setting up the git configuration..."
  # user
  if [ "${LTK_GIT_USER_NAME}" != "" ]; then
    git config --global user.name "${LTK_GIT_USER_NAME}"
  fi

  if [ "${LTK_GIT_USER_EMAIL}" != "" ]; then
    git config --global user.email "${LTK_GIT_USER_EMAIL}"
  fi
  git config --global init.defaultBranch master
  # core
  git config --global core.eol lf
  git config --global core.autocrlf false
  git config --global core.fileMode false
  git config --global core.packedGitLimit 128m
  git config --global core.packedGitWindowSize 128m
  # pack
  git config --global pack.deltaCacheSize 128m
  git config --global pack.packSizeLimit 128m
  git config --global pack.windowMemory 128m
  # pull push
  git config --global pull.ff only
  git config --global pull.rebase true
  git config --global push.default simple
  # http https
  git config --global http.postBuffer 128m
  git config --global https.postBuffer 128m
  # other
  git config --global fsck.zeroPaddedFilemode ignore
  git config --global fetch.fsck.zeroPaddedFilemode ignore
  git config --global receive.fsck.zeroPaddedFilemode ignore
  # store
  if is_mac; then
      git config --global credential.helper osxkeychain
  else
      git config --global credential.helper store
  fi
  fmt_information "Set up successfully."
  fmt_information "git user.name: ${LTK_GIT_USER_NAME}"
  fmt_information "git user.email: ${LTK_GIT_USER_EMAIL}"
}

main() {
  setup_optimize_git_config
}

main