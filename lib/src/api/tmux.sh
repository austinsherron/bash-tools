#!/usr/bin/env bash

source "${BASH_LIB}/args/validate.sh"


# NOTE: tmux must be installed to use the utils defined here
validate_installed tmux.sh tmux

#######################################
# Displays the current tmux window's name.
# Outputs:
#   Writes to stdout the current tmux window's name
#######################################
function tmux::window_name() {
    tmux display-message -p '#W'
}

#######################################
# Displays the current tmux window's id.
# Outputs:
#   Writes to stdout the current tmux window's id
#######################################
function tmux::window_idx() {
    tmux display-message -p '#I'
}

