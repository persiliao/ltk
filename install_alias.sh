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
  for rc in $(ls -al "${HOME}" | grep "shrc$" | awk '{print $9}'); do
    if ! grep -q -c ".ltk/commands" "${HOME}/${rc}"; then
      # shellcheck disable=SC2016
      echo '# Source ltk alias commands
# shellcheck disable=SC2045
for rc in $(ls "${HOME}/.ltk/commands") ; do
  # shellcheck disable=SC1090
  . "${HOME}/.ltk/commands/${rc}"
done' >> "${HOME}/${rc}"
    fi
  done
}

setup_install_alias() {
  if ! [ -d "${HOME}/.ltk" ]; then
    mkdir "${HOME}/.ltk"
  fi
  if cp -r "${LTK_DIRECTORY}/commands" "${HOME}/.ltk"; then
    setup_install_alias_bootstrap
  fi
}

main() {
  setup_install_alias
}

main
