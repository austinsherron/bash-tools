#!/usr/bin/env bash

source "${BASH_LIB}/api/git.sh"
source "${BASH_LIB}/api/tmux.sh"
source "${BASH_LIB}/log/utils.sh"

source "${BASH_TOOLS}/tools/git/_helpers/config.sh"


# The local env windows that every "dev" command acts on: one tmux window per
# worktree, all of them on a tmux server of their own (see: DEV_SERVER) so that
# they're independent of the session they're driven from.
#
# The module tracks a single "current" worktree -- the one the command was run
# from, unless a command points it elsewhere w/ window::use -- and derives that
# worktree's window name from it.

DEV_SERVER="dev"

WORKTREE=""
WINDOW_NAME=""
BASE_PANE_IDX=""


#######################################
# Runs a tmux command against the local env server.
# Arguments:
#   the tmux command to run, and its args
#######################################
function dtmux() {
    tmux -L "${DEV_SERVER}" "$@"
}

#######################################
# Points the window helpers at the worktree the command was run from.
#######################################
function window::init() {
    WORKTREE="$(git::worktree)"
    WINDOW_NAME="$(window::name "$(git::worktree_rel "${WORKTREE}")")"
    BASE_PANE_IDX="$(tmux::base_pane_idx)"
}

#######################################
# Points the window helpers at another worktree, so that they operate on it
# instead of the one the command was run from.
# Arguments:
#   path: the path of the worktree to operate on
#######################################
function window::use() {
    WORKTREE="${1}"
    WINDOW_NAME="$(window::name "$(git::worktree_rel "${WORKTREE}")")"
}

#######################################
# Checks if a worktree identifier belongs to a category's default worktree.
#
# A category's default worktree is the one named after its category. It's the
# stable home for that category: never removed, and where the session history of
# the category's ephemeral worktrees is archived so that it outlives them.
# Arguments:
#   rel: the "<category>/<item>" identifier to check
# Returns:
#   0 if the identifier belongs to a category default worktree, 1 otherwise
#######################################
function window::is_category_default() {
    local rel="${1}"

    [[ "${rel}" == */* ]] || return 1
    [[ "${rel%/*}" = "${rel#*/}" ]]
}

#######################################
# Renders a worktree's identifier ("<category>/<item>") as a window name. A
# category configured w/ an icon (see: [<repo>.icon]) is named by it; otherwise
# the category name is spelled out:
#
#     <icon> <item>    /  <category> > <item>
#     <icon>           /  <category>            (category default, main worktree)
#
# A category default worktree, and the main worktree, drop the item entirely: it
# only repeats the category.
# Arguments:
#   rel: the "<category>/<item>" identifier to render
# Outputs:
#   Writes the window name to stdout
#######################################
function window::name() {
    local rel="${1}"
    local category="${rel%%/*}"
    local item="${rel#*/}"

    local icon="" ; config::has_icon "${category}" && icon="$(config::icon_for "${category}")"

    if [[ "${rel}" != */* ]] || window::is_category_default "${rel}"; then
        echo "${icon:-${category}}"
        return 0
    fi

    if [[ -n "${icon}" ]]; then
        # two spaces: an icon carrying a variation selector or a ZWJ join often
        # renders wider than the cells tmux reserves for it, and the overflow
        # swallows a single separating space
        echo "${icon}  ${item}"
    else
        echo "${category} > ${item}"
    fi
}

#######################################
# Resolves a window name to its stable window id (e.g.: "@12"). tmux resolves
# name targets fuzzily, and work item names share prefixes constantly, so every
# command that acts on a window targets it by id instead.
# Arguments:
#   window: optional, defaults to the current worktree's window; the window name
#           to resolve
#   cmd: optional, defaults to the local env server; the tmux command to query
# Outputs:
#   Writes the window id to stdout, or nothing if there's no such window
#######################################
function window::id() {
    local window="${1:-${WINDOW_NAME}}"
    local cmd="${2:-dtmux}"

    # window names carry spaces, and an icon is separated from its item name by
    # two of them, so the name is everything past the first space -- taken as a
    # substring, since assigning to a field would rebuild the record and collapse
    # the run of spaces
    #
    # runs of spaces are collapsed on both sides before comparing, though: the
    # doubled separator is a rendering workaround (see: window::name), so a
    # window named w/ a single space is the same window, and a match can't turn
    # on how wide its icon happened to be. item names carry no spaces of their
    # own, so this stays an exact match on the part that identifies the worktree
    #
    # LC_ALL=C: this awk compares strings by collation, and emoji carry no
    # collation weight, so under a UTF-8 locale every icon compares equal to
    # every other -- a bare-icon name (a category default's, see: window::name)
    # would resolve to whichever icon window tmux happened to list first. bytes
    # are what's wanted here, and the separator collapsing below is ASCII either way
    #
    # no window (or no server at all) is an ordinary answer here, not a failure
    $cmd list-windows -a -F '#{window_id} #W' 2> /dev/null \
        | LC_ALL=C awk -v w="${window}" '
              function collapse(name) { gsub(/ +/, " ", name) ; return name }
              {
                  sep = index($0, " ")
                  if (collapse(substr($0, sep + 1)) == collapse(w)) {
                      print substr($0, 1, sep - 1) ; exit
                  }
              }' \
        || true
}

#######################################
# Checks if a window exists on the local env server.
# Arguments:
#   window: optional, defaults to the current worktree's window; the window name
#           to check
# Returns:
#   0 if the window exists, 1 otherwise
#######################################
function window::exists() {
    [[ -n "$(window::id "${1:-${WINDOW_NAME}}")" ]]
}

#######################################
# Displays the name of the session that holds a window on the current tmux
# server.
# Arguments:
#   window: the id of the window to locate
# Outputs:
#   Writes the session name to stdout, or nothing if there's no such window
#######################################
function window::session() {
    local window="${1}"

    # an unresolvable window is an ordinary answer here, not a failure
    tmux display-message -pt "${window}" '#{session_name}' 2> /dev/null || true
}

#######################################
# Displays a pane target ("<window id>.<pane index>") in the current worktree's
# window.
# Arguments:
#   pane: optional, defaults to 0; the pane's offset from the base pane index
# Outputs:
#   Writes the pane target to stdout
#######################################
function window::target() {
    local pane="${1:-0}"
    local id ; id="$(window::id)"

    echo "${id:-${WINDOW_NAME}}.$((BASE_PANE_IDX+pane))"
}

#######################################
# Displays new-window positioning flags (e.g.: "-a -t other-worktree") so that
# WINDOW_NAME is created in the same relative order as its window in the source
# (current) tmux session. Empty output appends the window at the end.
# Arguments:
#   cmd: the tmux command that manages the destination server
# Outputs:
#   Writes new-window positioning flags to stdout
#######################################
function window::order_flags() {
    local cmd="${1}"
    local -a source dev
    local i name

    mapfile -t source < <(tmux list-windows -F '#W' 2> /dev/null)
    mapfile -t dev < <($cmd list-windows -F '#W' 2> /dev/null)

    local si=-1
    for i in "${!source[@]}"; do
        [[ "${source[i]}" == "${WINDOW_NAME}" ]] && { si="${i}"; break; }
    done
    [[ "${si}" -lt 0 ]] && return 0

    # place before the first existing window that follows WINDOW_NAME in the source
    for ((i = si + 1; i < ${#source[@]}; i++)); do
        name="${source[i]}"
        if printf '%s\n' "${dev[@]}" | grep -qxF -- "${name}"; then
            echo "-b -t ${name}"
            return 0
        fi
    done

    # otherwise, place after the last existing window that precedes it
    for ((i = si - 1; i >= 0; i--)); do
        name="${source[i]}"
        if printf '%s\n' "${dev[@]}" | grep -qxF -- "${name}"; then
            echo "-a -t ${name}"
            return 0
        fi
    done
}

#######################################
# Creates the current worktree's window, w/ three panes, creating the session
# that holds it if it doesn't exist yet.
# Arguments:
#   -c: optional, defaults to the local env server; the tmux command to create
#       the window w/
#   -d: optional, multi-valued, defaults to "backend"; each pane's directory,
#       relative to the worktree
#######################################
function window::init_panes() {
    local cmd="dtmux"
    local pane_dirs=()

    local OPTIND=1
    while getopts "c:d:" opt; do
      case $opt in
        c) cmd="${OPTARG}" ;;
        d) pane_dirs+=("${OPTARG}") ;;
        \?) ulogger error "valid flags are -cd" >&2 ; return 1 ;;
      esac
    done
    shift $((OPTIND - 1))

    if $cmd list-sessions 2> /dev/null | grep -q .; then
        # local order
        # order="$(window::order_flags "$cmd")"
        # $cmd new-window "${order}" -n "${WINDOW_NAME}" -c "${WORKTREE}/${pane_dirs[0]:-backend}"
        $cmd new-window -n "${WINDOW_NAME}" -c "${WORKTREE}/${pane_dirs[0]:-backend}"
    else
        $cmd new-session -d -n "${WINDOW_NAME}" -c "${WORKTREE}/${pane_dirs[0]:-backend}"
    fi

    $cmd split-window -h -t "${WINDOW_NAME}" -c "${WORKTREE}/${pane_dirs[1]:-frontend}"
    $cmd split-window -v -t "${WINDOW_NAME}" -c "${WORKTREE}/${pane_dirs[2]:-backend}"
}

#######################################
# Opens the current worktree's window in the current tmux session, rather than
# on the local env server.
# Arguments:
#   dirs: optional, defaults to "backend" "backend" "/"; each pane's directory,
#         relative to the worktree
#######################################
function window::init_worktree() {
    local dirs=("$@")
    [[ "${#dirs[@]}" -gt 0 ]] || dirs=("backend" "backend" "/")

    local dir
    local args=()

    for dir in "${dirs[@]}"; do
        args+=(-d "${dir}")
    done

    window::init_panes -c "tmux" "${args[@]}"
}

#######################################
# Renumbers a session's windows, if it's configured to renumber them (see:
# renumber-windows).
#
# tmux honors that option itself only when a window is *closed*, so a window
# moved out of a session leaves a gap in its numbering behind.
# Arguments:
#   session: the name of the session to renumber
#######################################
function window::renumber() {
    local session="${1}"

    # the session is gone when the window that left was its last
    [[ -n "${session}" ]] || return 0
    tmux::is_session "${session}" || return 0

    # a session w/o the option set inherits the global one, and the format lookup
    # is what resolves that fallback: "show-options -v" reports only what the
    # session itself carries
    local renumber
    # "=<session>:" -- the exact-match window target form: "-t" takes a pane
    # target here, and a bare session name resolves to the wrong thing
    renumber="$(tmux display-message -pt "=${session}:" '#{renumber-windows}' 2> /dev/null || true)"
    [[ "${renumber}" == "1" ]] || return 0

    # -r renumbers the target session; it moves nothing
    tmux move-window -r -t "=${session}:"
}

#######################################
# Moves a window to another session on the current tmux server, creating the
# session if it doesn't exist yet.
#
# tmux can't wrap a session around a window that already exists, so a missing
# session is created detached, w/ the current worktree as its path, and the
# window it comes with is replaced by the one being moved in.
#
# The session the window came from is renumbered on the way out: tmux only
# renumbers a session when a window is closed in it, not when one moves away.
# Arguments:
#   window: the id of the window to move
#   session: the name of the session to move the window to
# Returns:
#   0 if the window was moved, 1 otherwise
#######################################
function window::move() {
    local window="${1}"
    local session="${2}"

    local source ; source="$(window::session "${window}")"

    # an existing session takes the window at its first free index; a new one
    # takes it in place of the window it was created with
    local target="=${session}:"
    local flags=()

    if ! tmux::is_session "${session}"; then
        ulogger info "creating session '${session}'"

        local placeholder
        placeholder="$(
            tmux new-session -d -s "${session}" -c "${WORKTREE}" -P -F '#{window_index}'
        )" || return 1

        # -k: the placeholder is killed rather than left beside the window that
        # replaces it, so the moved window lands on the session's base index
        target="=${session}:${placeholder}"
        flags=(-k)
    fi

    if ! tmux move-window ${flags[@]+"${flags[@]}"} -s "${window}" -t "${target}"; then
        # the session was ours to begin w/, so it goes back out w/ the failure
        [[ "${#flags[@]}" -eq 0 ]] || tmux kill-session -t "=${session}"
        return 1
    fi

    window::renumber "${source}"
}

#######################################
# Tears down a window on both the local env server and the current one.
# Arguments:
#   window: the name of the window to kill
#######################################
function window::kill() {
    local window="${1}"
    local cmd id

    for cmd in "dtmux" "tmux"; do
        id="$(window::id "${window}" "${cmd}")"
        [[ -n "${id}" ]] || continue

        $cmd kill-window -t "${id}" 2> /dev/null || true
    done
}
