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

setup_install_alias_bootstrap() {
  # shellcheck disable=SC2010
  for config_file in $(ls -al "${HOME}" | grep "shrc$" | awk '{print $9}'); do
    if ! grep -q -c ".ltk/commands" "${HOME}/${config_file}"; then
      # shellcheck disable=SC2016
      echo '# Source ltk alias commands
# shellcheck disable=SC2045
for config_file in $(ls "${HOME}/.ltk/commands") ; do
  # shellcheck disable=SC1090
  . "${HOME}/.ltk/commands/${config_file}"
done
unset config_file
' >> "${HOME}/${config_file}"
    fi
  done
  unset config_file
}

setup_install_alias() {
  if ! [ -d "${HOME}/.ltk" ]; then
    mkdir -p "${HOME}/.ltk"
  fi
  if cp -r "${LTK_DIRECTORY}/commands" "${HOME}/.ltk"; then
    setup_install_alias_bootstrap
  fi
  fmt_information "Secondary commands are installed successfully"
}

main() {
  setup_install_alias
}

main
