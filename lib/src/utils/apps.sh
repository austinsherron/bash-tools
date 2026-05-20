#!/usr/bin/env bash

source "${BASH_LIB}/core/str.sh"


#######################################
# Displays the name of the "frontmost" application.
#
# NOTE: Output is lowercased.
#
# Outputs:
#   Writes to stdout the name of the "frontmost" application
#######################################
function apps::front() {
    str::lower "$(lsappinfo info -only name "$(lsappinfo front)" | cut -d "=" -f2 | xargs)"
}

