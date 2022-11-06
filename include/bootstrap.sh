#!/bin/bash

# Author:  Persi.Liao <xiangchu.liao AT gmail.com>
#
# Notes: Linux Took Kit
#
# Project home page:
#    https://github.com/persiliao/ltk

set -e

export PATH=/sbin:/bin:/usr/sbin:/usr/bin:/usr/local/sbin:/usr/local/bin

if [ -z "${LTK_DIRECTORY}" ]; then
  fmt_error "The directory cannot be empty."
  exit 1
fi

# Autoload
. "${LTK_DIRECTORY}/include/functions.sh"

# Set terminal colors
setup_color