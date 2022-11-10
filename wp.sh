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

setup_install_wp_cli() {
  if ! command_exists wp; then
    fmt_tips "Do you want to install wp cli? [Y/n] "
    read -r opt
    case $opt in
      y*|Y*|"") ;;
      n*|N*) fmt_notice "wp cli install skipped."; return ;;
      *) fmt_notice "Invalid choice. wp cli install skipped."; return ;;
    esac

    if curl -o "${LTK_WP_CLI_PATH}" https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar; then
      chmod +x "${LTK_WP_CLI_PATH}"
      mv "${LTK_WP_CLI_PATH}" /usr/local/bin/wp
      fmt_information "wp cli install successfully."
    else
      fmt_notice "Cancelled wp cli install."
      rm -rf "${LTK_WP_CLI_PATH}"
    fi
  fi

  if command_exists wp; then
    if ! command_exists php; then
      fmt_error "php is not installed. wp cli needs to depend on php"
    else
      php -v
      wp --info
    fi
  fi
}

main() {
  LTK_WP_CLI_PATH="${HOME}/wp-cli.phar"
  setup_install_wp_cli
}

main
