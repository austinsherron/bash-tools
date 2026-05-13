#!/usr/bin/env bash

source "${BASH_LIB}/args/validate.sh"
source "${BASH_LIB}/core/str.sh"


# NOTE: tmux must be installed to use the utils defined here
validate_installed tmux.sh tmux

#######################################
# Displays the current tmux window's name.
# Outputs:
#   Writes to stdout the current tmux window's name
#######################################
function tmux::is() {
    [[ -n "${TMUX+x}" ]]
}

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
# Displays the windows in the active tmux session.
# Arguments:
#   session: optional, defaults to active session; the name of the session from which to list windows
# Outputs:
#   Writes to stdout the windows in the provided/active tmux session.
#######################################
function tmux::list_windows() {
    local session="${1:-}"
    local session_flag=""

    [[ -n "${session}" ]] && session_flag="-t =${session}"

    tmux list-windows ${session_flag} -F '#W'
}

#######################################
# Checks if a tmux window w/ the provided name exists in a session.
# Arguments:
#   window: the name of the window to check for existence
#   session: optional, defaults active session; the name of the session in which to check
# Returns:
#   0 if a tmux window w/ the provided name exists in the provided/active session, 1 otherwise.
#######################################
function tmux::is_window() {
    tmux::list_windows "${2:-}" 2> /dev/null | grep -qF "${1}"
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
# Checks if a session w/ the provided name exists.
# Arguments:
#   session: the name of the session to check
# Returns:
#   0 if the provided session exists, 1 otherwise
#######################################
function tmux::is_session() {
    tmux has-session -t "=${1}" 2> /dev/null
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

#######################################
# Display to stdout the starting index for tmux panes w/in a window.
# Outputs:
#   Writes to stdout the starting index for tmux panes w/in a window
#######################################
function tmux::base_pane_idx() {
    tmux show-option -gv pane-base-index
}

#######################################
# Displays a tmux "location" based on the provided params.
#
# Flags determine which location components are included in output, and in what
# order. By default, "source" location (i.e.: the location from which the
# function is called) is displayed in the following format: session.window.pane.
# Arguments:
#   -s: include session name in output
#   -w: include window name in output
#   -p: include pane number in output
#   -d: the separator to use; defaults to "."
#   -u: display the user's location, instead of the location of the function 
#       call site
# Outputs:
#   
#######################################
function tmux::location() {
    local fmt_parts=()
    local fmt
    local sep="."
    local user=""

    local OPTIND=1
    while getopts ":swpud:" opt; do
      case $opt in
        s) fmt_parts+=("#S") ;;
        w) fmt_parts+=("#W") ;;
        p) fmt_parts+=("#P") ;;
        d) sep="${OPTARG}" ;;
        u) user="true" ;;
        :) ulogger error "arg required for -d" >&2 ; return 1 ;;
        \?) ulogger error "valid flags are -swpud" >&2 ; return 1 ;;
      esac
    done

    [[ "${#fmt_parts[@]}" -eq 0 ]] && fmt_parts=("#S" "#W" "#P")
    fmt="$(str::join "${sep}" ${fmt_parts[@]})"

    if [[ -z "${user}" ]]; then
        tmux display-message -p -t "${TMUX_PANE}" "${fmt}"
    else
        tmux display-message -p "${fmt}"
    fi
}
