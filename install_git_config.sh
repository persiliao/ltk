#!/bin/bash

# Author: Persi.Liao <xiangchu.liao AT gmail.com>
# Notes: Linux Took Kit
# Project home page: https://github.com/persiliao/ltk

cd "$(dirname "$0")" || {
  fmt_error "You do not have permission to do this."
  exit 1
}

LTK_DIRECTORY="$(pwd)"
. "${LTK_DIRECTORY}/bootstrap.sh"

setup_git_user_name() {
  while :; do
    fmt_tips "Please enter the name used for git commit (e.g., Persi.Liao): "
    read -r LTK_GIT_USER_NAME
    if [ -n "${LTK_GIT_USER_NAME}" ]; then
      git config --global user.name "${LTK_GIT_USER_NAME}"
      break
    else
      fmt_error "Invalid name. Please try again."
    fi
  done
}

setup_git_user_email() {
  while :; do
    fmt_tips "Please enter the email address used for git commit (e.g., git@git.com): "
    read -r LTK_GIT_USER_EMAIL
    if validate_email "${LTK_GIT_USER_EMAIL}"; then
      git config --global user.email "${LTK_GIT_USER_EMAIL}"
      break
    else
      fmt_error "Invalid email address. Please try again."
    fi
  done
}

setup_git_config() {
  if ! command_exists git; then
    fmt_error "You haven't installed git yet."
    exit 1
  fi

  fmt_tips "You want to start setting up your git configuration? [Y/n] "
  read -r opt
  case $opt in
    y*|Y*|"") ;;
    *) fmt_notice "Invalid choice. Setting git configuration skipped."; return ;;
  esac

  # Setup user name
  if ! git config --global --get user.name > /dev/null; then
    setup_git_user_name
  fi

  # Setup user email
  if ! git config --global --get user.email > /dev/null; then
    setup_git_user_email
  fi

  fmt_notice "Begin setting up the git configuration..."

  # Core configurations
  git config --global init.defaultBranch master
  git config --global core.eol lf
  git config --global core.autocrlf false
  git config --global core.fileMode false
  git config --global core.packedGitLimit 128m
  git config --global core.packedGitWindowSize 128m
  git config --global core.quotepath false
  git config --global gui.encoding utf-8
  git config --global i18n.commit.encoding utf-8
  git config --global i18n.logoutputencoding utf-8

  # Pack configurations
  git config --global pack.deltaCacheSize 128m
  git config --global pack.packSizeLimit 128m
  git config --global pack.windowMemory 128m

  # Pull and push configurations
  git config --global pull.ff only
  git config --global pull.rebase true
  git config --global push.default simple

  # HTTP and HTTPS settings
  git config --global http.postBuffer 128m
  git config --global https.postBuffer 128m

  # Other configurations
  git config --global fsck.zeroPaddedFilemode ignore
  git config --global fetch.fsck.zeroPaddedFilemode ignore
  git config --global receive.fsck.zeroPaddedFilemode ignore

  # Credential helper setup
  if is_mac; then
      git config --global credential.helper osxkeychain
  else
      git config --global credential.helper cache
  fi

  fmt_information "Git configuration setup successfully."
}

main() {
  setup_git_config
}

main
