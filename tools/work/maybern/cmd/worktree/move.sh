#!/usr/bin/env bash


# The "worktree move" command; sourced by main.sh.

# sessions whose names match this are internal, and never move targets;
# "_"-prefixed is the convention for hidden tmux objects in this config (see
# also: tmux-switch-session)
SESSION_EXCLUDE="^(_|popup-)"

## help ########################################################################

function wt::help::move() {
cat <<help
DESCRIPTION

    Moves a worktree's window to another session on the current tmux server,
    creating the session -- w/ the worktree as its path -- if it doesn't exist
    yet.

    The worktree is the one given, or the one picked w/ fzf when given
    -c|--choose, or else the current one.

    The window is the one named after the worktree (see: [list]), as opened by
    [open]; a worktree that has none in this server has nothing to move. Only
    the current server's windows move: the local env windows on the "dev" server
    are a server of their own, and tmux can't move a window between servers.

    The session is picked w/ fzf when it isn't given, from the sessions that
    aren't internal (/${SESSION_EXCLUDE}/) and aren't the window's own; a typed-in
    session that doesn't exist yet is accepted, and created.

    The session the window leaves keeps its numbering tidy: tmux applies
    renumber-windows itself only when a window is *closed* in a session, not
    when one moves away, so the gap is closed here for a session configured to
    renumber. Moving a session's last window leaves it empty, so tmux destroys
    it.

USAGE

    ${WT_USAGE[move]}

ALIASES

    $(aliases_for WT_ALIASES move)

POSITIONAL ARGUMENTS

    WORKTREE        optional, defaults to the current worktree; the
                    "<category>/<item>" identifier of the worktree whose window
                    to move

OPTIONS

    -s              optional, picked w/ fzf otherwise; the session to move the
                    window to, created if it doesn't exist yet

FLAGS

    -c, --choose    pick the worktree w/ fzf instead of using the current one
    -h, --help      display this message
help
}

## helpers #####################################################################

# Selects a session on the current tmux server w/ fzf, accepting a typed-in
# session that doesn't exist yet.
# Arguments:
#   skip: optional; a session to leave out of the candidates
function __wt::select_session() {
    local skip="${1:-}"

    local session
    local candidates=()

    while IFS= read -r session; do
        [[ -n "${skip}" && "${session}" == "${skip}" ]] && continue
        candidates+=("${session}")
    done < <(
        tmux list-sessions -F '#{session_name}' 2> /dev/null \
            | grep -Ev "${SESSION_EXCLUDE}" || true
    )

    # every candidate can be excluded and the selection still stands -- the query
    # names the session to create -- so an empty candidate list isn't a failure
    # to fail the pipeline w/ (see: pipefail)
    { [[ "${#candidates[@]}" -eq 0 ]] || printf '%s\n' "${candidates[@]}" ; } \
        | fzf --ansi --print-query --prompt='session> ' | tail -1
}

## command #####################################################################

function wt::move() {
    local session=""
    local choose=""

    # getopts can't parse long forms, so they're folded into their short ones first
    local arg
    local argv=()

    for arg in "$@"; do
        case "${arg}" in
          --choose) argv+=(-c) ;;
          *) argv+=("${arg}") ;;
        esac
    done
    set -- ${argv[@]+"${argv[@]}"}

    local OPTIND=1
    while getopts "cs:" opt; do
      case $opt in
        c) choose="true" ;;
        s) session="${OPTARG}" ;;
        \?) ulogger error "valid flags are -cs" >&2 ; return 1 ;;
      esac
    done
    shift $((OPTIND - 1))

    local rel ; rel="$(__wt::target "${1:-}" "${choose}" "move")" || return 1
    [[ -n "${rel}" ]] || return 0

    local path ; path="$(__wt::resolve "${rel}")" || return 1

    window::use "${path}"

    # the current server, not the local env one: [open]'s windows live here, and
    # a window can't cross servers
    local id ; id="$(window::id "${WINDOW_NAME}" "tmux")"

    if [[ -z "${id}" ]]; then
        ulogger error "no window for '${rel}' in this tmux server; run \"dev worktree open\" to open one"
        return 1
    fi

    local current ; current="$(window::session "${id}")"

    [[ -n "${session}" ]] || session="$(__wt::select_session "${current}")"
    validate_required "-s <session>" "${session}" || return 1

    if [[ "${session}" == "${current}" ]]; then
        ulogger warn "window '${WINDOW_NAME}' is already in session '${session}'"
        return 0
    fi

    window::move "${id}" "${session}" || return 1
    ulogger info "moved window '${WINDOW_NAME}' from session '${current}' to '${session}'"
}
