#!/usr/bin/env bash

set -Eeuo pipefail


# the ring store file of a stack: creation order, i.e.: cycle order
function __stack::file() {
    echo "${__STACK_DIR}/${1}"
}

# the mru store file of a stack: visibility order, newest == visible
function __stack::mru_file() {
    echo "$(__stack::file "${1}").mru"
}

# the holding session for a stack's detached panes
function stack::session() {
    echo "${__STACK_SESS_PREFIX}${1}"
}

# the name of the stack a pane would create
function stack::name_for() {
    echo "${1#%}"
}

# the pane a sub-command should operate on: its first positional arg, falling
# back to the calling pane
function stack::target() {
    while [[ $# -gt 0 ]]; do
        case "${1}" in
          -*) shift ;;
          *) echo "${1}" ; return 0 ;;
        esac
    done

    tmux::pane_id
}
