#!/bin/sh

command_exists() {
  command -v "$@" >/dev/null 2>&1
}

is_root() {
  return "$(id -u)"
}

user_can_sudo() {
  # Check if sudo is installed
  command_exists sudo || return 1
  # The following command has 3 parts:
  #
  # 1. Run `sudo` with `-v`. Does the following:
  #    • with privilege: asks for a password immediately.
  #    • without privilege: exits with error code 1 and prints the message:
  #      Sorry, user <username> may not run sudo on <hostname>
  #
  # 2. Pass `-n` to `sudo` to tell it to not ask for a password. If the
  #    password is not required, the command will finish with exit code 0.
  #    If one is required, sudo will exit with error code 1 and print the
  #    message:
  #    sudo: a password is required
  #
  # 3. Check for the words "may not run sudo" in the output to really tell
  #    whether the user has privileges or not. For that we have to make sure
  #    to run `sudo` in the default locale (with `LANG=`) so that the message
  #    stays consistent regardless of the user's locale.
  #
  # shellcheck disable=SC1007
  ! LANG= sudo -n -v 2>&1 | grep -q "may not run sudo"
}

# The [ -t 1 ] check only works when the function is not called from
# a subshell (like in `$(...)` or `(...)`, so this hack redefines the
# function at the top level to always return false when stdout is not
# a tty.
if [ -t 1 ]; then
  is_tty() {
    true
  }
else
  is_tty() {
    false
  }
fi

# This function uses the logic from supports-hyperlinks[1][2], which is
# made by Kat Marchán (@zkat) and licensed under the Apache License 2.0.
# [1] https://github.com/zkat/supports-hyperlinks
# [2] https://crates.io/crates/supports-hyperlinks
#
# Copyright (c) 2021 Kat Marchán
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
supports_hyperlinks() {
  # $FORCE_HYPERLINK must be set and be non-zero (this acts as a logic bypass)
  if [ -n "$FORCE_HYPERLINK" ]; then
    [ "$FORCE_HYPERLINK" != 0 ]
    return $?
  fi

  # If stdout is not a tty, it doesn't support hyperlinks
  is_tty || return 1

  # DomTerm terminal emulator (domterm.org)
  if [ -n "$DOMTERM" ]; then
    return 0
  fi

  # VTE-based terminals above v0.50 (Gnome Terminal, Guake, ROXTerm, etc)
  if [ -n "$VTE_VERSION" ]; then
    [ $VTE_VERSION -ge 5000 ]
    return $?
  fi

  # If $TERM_PROGRAM is set, these terminals support hyperlinks
  case "$TERM_PROGRAM" in
  Hyper|iTerm.app|terminology|WezTerm) return 0 ;;
  esac

  # kitty supports hyperlinks
  if [ "$TERM" = xterm-kitty ]; then
    return 0
  fi

  # Windows Terminal also supports hyperlinks
  if [ -n "$WT_SESSION" ]; then
    return 0
  fi

  # Konsole supports hyperlinks, but it's an opt-in setting that can't be detected
  # https://github.com/ohmyzsh/ohmyzsh/issues/10964
  # if [ -n "$KONSOLE_VERSION" ]; then
  #   return 0
  # fi

  return 1
}

# Adapted from code and information by Anton Kochkov (@XVilka)
# Source: https://gist.github.com/XVilka/8346728
supports_truecolor() {
  case "$COLORTERM" in
  truecolor|24bit) return 0 ;;
  esac

  case "$TERM" in
  iterm           |\
  tmux-truecolor  |\
  linux-truecolor |\
  xterm-truecolor |\
  screen-truecolor) return 0 ;;
  esac

  return 1
}

fmt_link() {
  # $1: text, $2: url, $3: fallback mode
  if supports_hyperlinks; then
    printf '\033]8;;%s\033\\%s\033]8;;\033\\\n' "$2" "$1"
    return
  fi

  case "$3" in
  --text) printf '%s\n' "$1" ;;
  --url|*) fmt_underline "$2" ;;
  esac
}

setup_color() {
  # Only use colors if connected to a terminal
  if ! is_tty; then
    FMT_RAINBOW=""
    FMT_RED=""
    FMT_GREEN=""
    FMT_YELLOW=""
    FMT_BLUE=""
    FMT_BOLD=""
    FMT_RESET=""
    return
  fi

  if supports_truecolor; then
    FMT_RAINBOW="
      $(printf '\033[38;2;255;0;0m')
      $(printf '\033[38;2;255;97;0m')
      $(printf '\033[38;2;247;255;0m')
      $(printf '\033[38;2;0;255;30m')
      $(printf '\033[38;2;77;0;255m')
      $(printf '\033[38;2;168;0;255m')
      $(printf '\033[38;2;245;0;172m')
    "
  else
    # shellcheck disable=SC2034
    FMT_RAINBOW="
      $(printf '\033[38;5;196m')
      $(printf '\033[38;5;202m')
      $(printf '\033[38;5;226m')
      $(printf '\033[38;5;082m')
      $(printf '\033[38;5;021m')
      $(printf '\033[38;5;093m')
      $(printf '\033[38;5;163m')
    "
  fi

  FMT_RED=$(printf '\033[31m')
  FMT_GREEN=$(printf '\033[32m')
  FMT_YELLOW=$(printf '\033[33m')
  FMT_BLUE=$(printf '\033[34m')
  FMT_BOLD=$(printf '\033[1m')
  FMT_RESET=$(printf '\033[0m')
}

fmt_underline() {
  is_tty && printf '\033[4m%s\033[24m\n' "$*" || printf '%s\n' "$*"
}

# shellcheck disable=SC2016 # backtick in single-quote
fmt_code() {
  is_tty && printf '`\033[2m%s\033[22m`\n' "$*" || printf '`%s`\n' "$*"
}

fmt_error() {
  printf '%sError: %s%s\n' "${FMT_BOLD}${FMT_RED}" "$*" "$FMT_RESET" >&2
}

fmt_notice() {
  printf '%sNotice: %s%s\n' "${FMT_BOLD}${FMT_BLUE}" "$*" "$FMT_RESET" >&2
}

fmt_information() {
  printf '%s%s%s\n' "${FMT_BOLD}${FMT_GREEN}" "$*" "$FMT_RESET" >&2
}

fmt_tips() {
  printf '%s%s%s' "${FMT_BOLD}${FMT_YELLOW}" "$*" "$FMT_RESET" >&2
}

get_user_home_dir() {
  LTK_USER_NAME=$1
  if [ "${LTK_USER_NAME}" = "" ]; then
    fmt_error "The user name cannot be empty."
    return 1
  fi

  LTK_USER_INFO=$(grep "${LTK_USER_NAME}" /etc/passwd | head -1)
  # shellcheck disable=SC2039
  # shellcheck disable=SC2206
  LTK_USER_INFO_ARRAY=(${LTK_USER_INFO//:/ })
  # shellcheck disable=SC2039
  echo "${LTK_USER_INFO_ARRAY[5]}"
}

generate_random_str() {
  LTK_STRING_LENGTH=$1
  if [ "${LTK_STRING_LENGTH}" = "" ]; then
    LTK_STRING_LENGTH=16
  fi

  < /dev/urandom tr -dc 'A-Za-z0-9' | head -c${LTK_STRING_LENGTH}
}

generate_password() {
  LTK_PASSWORD_LENGTH=$1
  if [ "${LTK_PASSWORD_LENGTH}" = "" ]; then
    LTK_PASSWORD_LENGTH=16
  fi

  < /dev/urandom tr -dc 'A-Za-z0-9!@#$%^&*()_+' | head -c${LTK_PASSWORD_LENGTH}
}

generate_ssh_key() {
  LTK_KEY_FILE_PATH=$1
  if [ "${LTK_KEY_FILE_PATH}" = "" ]; then
    fmt_error "Please provide the key file path."
    return 1
  fi
  ssh-keygen -t rsa -f "${LTK_KEY_FILE_PATH}"
  return 0
}

deploy_ssh_public_key() {
  LTK_USER_NAME=$1
  if [ "${LTK_USER_NAME}" = "" ]; then
    LTK_USER_NAME=$(id -u -n)
  fi

  LTK_KEY_FILE_PATH=$2
  if [ ! -f "${LTK_KEY_FILE_PATH}" ]; then
    fmt_error "Public key file not exits. path: ${LTK_KEY_FILE_PATH}"
    return 1
  fi

  LTK_USER_HOME=$(get_user_home_dir "${LTK_USER_NAME}")

  LTK_USER_SSH_DIRECTORY="${LTK_USER_HOME}/.ssh"
  LTK_USER_SSH_AUTHORIZED_KEYS_PATH="${LTK_USER_SSH_DIRECTORY}/authorized_keys"

  test -d "${LTK_USER_SSH_DIRECTORY}" || mkdir -p "${LTK_USER_SSH_DIRECTORY}"
  chmod 0700 "${LTK_USER_SSH_DIRECTORY}"
  test -f "${LTK_USER_SSH_AUTHORIZED_KEYS_PATH}" || touch "${LTK_USER_SSH_AUTHORIZED_KEYS_PATH}"
  chmod 0600 "${LTK_USER_SSH_AUTHORIZED_KEYS_PATH}"
  chown "${LTK_USER_NAME}" -R "${LTK_USER_SSH_DIRECTORY}"
  cat "${LTK_KEY_FILE_PATH}" >> "${LTK_USER_SSH_AUTHORIZED_KEYS_PATH}"

  return 0
}

check_in_docker() {
  if ! grep -q -i -c systemd /proc/1/sched; then
    return 0
  else
    return 1
  fi
}

systemd_service_restart() {
  if ! command_exists "systemctl"; then
    fmt_error "Command ${FMT_GREEN}systemctl${FMT_RESET} ${FMT_RED}not found."
    return 1
  fi

  LTK_SERVICE=$1
  if [ "${LTK_SERVICE}" = "" ]; then
    fmt_error "The service cannot be empty."
    return 1
  fi

  fmt_notice "${LTK_SERVICE} service is restarting."
  if systemctl restart "${LTK_SERVICE}"; then
    fmt_information "${LTK_SERVICE} service restarted successfully."
    return 0
  else
    fmt_error "${LTK_SERVICE} service restart failed."
    return 1
  fi
}

is_redhat() {
  if [ -f /etc/redhat-release ]; then
    return 0
  else
    return 1
  fi
}

is_ubuntu() {
  if command_exists lsb_release; then
    return 0
  else
    return 1
  fi
}

is_mac() {
  if [ "$(uname)" = "Darwin" ]; then
    return 0
  else
    return 1
  fi
}

validate_email() {
  if echo "${1}" | grep -q -E -c "[A-Za-z0-9._]+@[A-Za-z0-9.]+\.[a-zA-Z]{2,4}"; then
    return 0
  else
    return 1
  fi
}
