#!/usr/bin/env bash

source "${BASH_LIB}/args/validate.sh"
source "${BASH_LIB}/core/str.sh"


# NOTE: tmux must be installed to use the utils defined here
validate_installed tmux.sh tmux

#######################################
# Checks if the caller is in tmux.
# Arguments:
#   -e: exit if not in tmux
# Outputs:
#   Writes to stdout the current tmux window's name
#######################################
function tmux::is() {
    local exit=""

    local OPTIND=1
    while getopts "e" opt; do
      case $opt in
        e) exit="true" ;;
        \?) ulogger error "valid flags are -e" >&2 ; return 1 ;;
      esac
    done

    [[ -n "${TMUX+x}" ]] && return 0
    [[ -z "${exit}" ]] && return 1

    exit 0
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
    # -x: window names derived from work item names share prefixes constantly, so
    # a substring match is not good enough
    tmux::list_windows "${2:-}" 2> /dev/null | grep -qxF -- "${1}"
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
#   -t: the pane to locate, defaulting to the call site's own (${TMUX_PANE});
#       ignored w/ -u
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
    local target="${TMUX_PANE:-}"

    local OPTIND=1
    while getopts ":swput:d:" opt; do
      case $opt in
        s) fmt_parts+=("#S") ;;
        w) fmt_parts+=("#W") ;;
        p) fmt_parts+=("#P") ;;
        d) sep="${OPTARG}" ;;
        t) target="${OPTARG}" ;;
        u) user="true" ;;
        :) ulogger error "arg required for -${OPTARG}" >&2 ; return 1 ;;
        \?) ulogger error "valid flags are -swput and -d" >&2 ; return 1 ;;
      esac
    done

    [[ "${#fmt_parts[@]}" -eq 0 ]] && fmt_parts=("#S" "#W" "#P")
    fmt="$(str::join "${sep}" ${fmt_parts[@]})"

    # w/out a pane to aim at, tmux answers for whatever the client is looking at
    if [[ -n "${user}" ]] || [[ -z "${target}" ]]; then
        tmux display-message -p "${fmt}"
    else
        tmux display-message -p -t "${target}" "${fmt}"
    fi
}

#######################################
# Displays a pane's unique, stable id (e.g.: "%12"). Unlike session:window.pane,
# a pane id survives window renumbering and moves.
# Arguments:
#   target: optional, defaults to the calling pane (${TMUX_PANE}), or, absent
#           that, the active pane; the pane to resolve
# Outputs:
#   Writes the pane id to stdout
#######################################
function tmux::pane_id() {
    # TMUX_PANE is only exported to shells started *in* a pane, so it's absent
    # under "run-shell"/hooks; fall back to the active pane there
    local -r target="${1:-${TMUX_PANE:-}}"

    if [[ -z "${target}" ]]; then
        tmux display-message -p '#{pane_id}'
    else
        tmux display-message -pt "${target}" '#{pane_id}'
    fi
}

#######################################
# Checks whether a pane still exists.
# Arguments:
#   pane_id: the pane id to check (e.g.: "%12")
# Returns:
#   0 if the pane exists, 1 otherwise
#######################################
function tmux::pane_alive() {
    local -r pane_id="${1}"
    # display-message -t doesn't reliably fail for a missing pane, so check
    # membership in the global pane list instead
    tmux list-panes -a -F '#{pane_id}' 2> /dev/null | grep -qxF -e "${pane_id}"
}

#######################################
# Checks whether a pane is visible, i.e.: session is attached + window/pane are active.
# Arguments:
#   pane_id: the pane id to check (e.g.: "%12")
# Returns:
#   0 if the pane is visible, 1 otherwise
#######################################
function tmux::pane_visible() {
    local -r pane_id="${1}"
    local attached wactive pactive

    read -r attached wactive pactive < <(
        tmux display-message -pt "${pane_id}" \
            '#{session_attached} #{window_active} #{pane_active}' 2> /dev/null
    ) || return 1

    [[ "${attached:-0}" -gt 0 ]] && [[ "${wactive}" == "1" ]] && [[ "${pactive}" == "1" ]]
}

#######################################
# Displays the name of the window containing a pane.
# Arguments:
#   pane_id: the pane id whose window name to resolve (e.g.: "%12")
# Outputs:
#   Writes the window name to stdout
#######################################
function tmux::pane_window_name() {
    local -r pane_id="${1}"
    tmux display-message -pt "${pane_id}" '#{window_name}'
}

#######################################
# Focuses a pane by id, switching the client's session/window as needed. Works
# across sessions.
# Arguments:
#   pane_id: the pane id to focus (e.g.: "%12")
# Returns:
#   0 on success, 1 if the pane can't be resolved
#######################################
function tmux::focus_pane() {
    local -r pane_id="${1}"
    local target

    target="$(tmux display-message -pt "${pane_id}" '#{session_name}:#{window_index}')" || return 1

    tmux switch-client -t "${target}" || return 1
    tmux select-window -t "${target}" 2> /dev/null || true
    tmux select-pane -t "${pane_id}"
}
