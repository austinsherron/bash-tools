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

#######################################
# Displays the current tmux session's name.
# Outputs:
#   Writes to stdout the current tmux session's name
#######################################
function tmux::session_name() {
    tmux display-message -p '#S'
}

#######################################
# Displays the tmux layout env var key for the provided target (i.e.: window name). For example:
#   tmux::layout "lua-tools" == "TMUX_LUA_TOOLS_LAYOUT"
#   tmux::layout "dotfiles" == "TMUX_DOTFILES_LAYOUT"
# Arguments:
#   target: the identifier of target (i.e.: window name) for which to construct a layout key
# Outputs:
#   Writes to stdout a tmux layout env var key constructed for the provided target
#######################################
function tmux::layout() {
    local -r target="${1:-$(tmux::window_name)}"
    local -r layout_key="$(str::upper "tmux_${target}_layout")"

    echo "${layout_key//\-/_}"
}
