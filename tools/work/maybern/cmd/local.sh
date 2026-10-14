#!/usr/bin/env bash

source "${BASH_LIB}/log/utils.sh"

source "${BASH_TOOLS}/tools/work/maybern/_helpers/window.sh"


# The "local" command group: the local env session for a single worktree -- the
# window that runs its server, its frontend and its celery worker (see:
# window::init_panes). Every command here acts on the worktree it was run from.

# shellcheck disable=SC2034
declare -A LOCAL_CMDS=(
    [start]="start"
    [stop]="stop"
    [show]="show"
    [hide]="hide"
    [restart]="restart"
    [destroy]="destroy"
    [list]="list"
)

# shellcheck disable=SC2034
declare -A LOCAL_DESCRIPTIONS=(
    [start]="start services in the current worktree's local env window"
    [stop]="stop the services running in the local env window"
    [show]="open the current worktree's local env window in a tmux popup"
    [hide]="close the local env popup"
    [restart]="execute [stop], then [start]"
    [destroy]="execute [stop] and tear down the local env window"
    [list]="list local env windows"
)

LOCAL_GROUP_USAGE="dev local <cmd> {flags}"

declare -A LOCAL_USAGE=(
    [start]="dev local start"
    [stop]="dev local stop"
    [show]="dev local show"
    [hide]="dev local hide"
    [restart]="dev local restart"
    [destroy]="dev local destroy"
    [list]="dev local list"
)

# shellcheck disable=SC2034
declare -A LOCAL_ALIASES=(
    [s]=start
    [init]=start
    [i]=start
    [up]=start
    [u]=start
    [down]=stop
    [d]=stop
    [view]=show
    [v]=show
    [h]=hide
    [close]=hide
    [c]=hide
    [x]=hide
    [r]=restart
    [kill]=destroy
    [k]=destroy
    [teardown]=destroy
    [t]=destroy
    [X]=destroy
    [ls]=list
    [l]=list
)

## help ########################################################################

function local::help() {
cat <<help
DESCRIPTION

    Manages the local env session for the current worktree.

    A worktree's local env is a single window on the "dev" tmux server, split
    into three panes: the backend server, the frontend dev server and a celery
    worker. The window is created on demand -- by [start] or [show] -- and lives
    until [destroy] kills it, or until the worktree is removed.

    Because the window lives on a separate tmux server, it's viewed as a popup
    overlay ([show]/[hide]) rather than as a window of the current session.

USAGE

    ${LOCAL_GROUP_USAGE}

COMMANDS

$(cmd_descriptions LOCAL_DESCRIPTIONS)

    run "dev local <cmd> -h" for a command's own help

ALIASES

    $(aliases_for GROUP_ALIASES local)

POSITIONAL ARGUMENTS

    CMD             the command to run

FLAGS

    -h, --help      display this message
help
}

function local::help::start() {
cat <<help
DESCRIPTION

    Starts the current worktree's services, creating its local env window first
    if it doesn't exist yet.

    Services are started by sending their commands to the window's panes:

        just run-server             the backend
        pnpm start:subdomains       the frontend
        just run-celery             the worker

    Only one worktree runs services at a time -- they'd contend for the same
    ports -- so the services of every *other* local env window are stopped
    first, as if by [stop].

USAGE

    ${LOCAL_USAGE[start]}

ALIASES

    $(aliases_for LOCAL_ALIASES start)

FLAGS

    -h, --help      display this message
help
}

function local::help::stop() {
cat <<help
DESCRIPTION

    Stops the services running in the current worktree's local env window, by
    sending each of its panes an interrupt.

    The window itself is left in place, ready for [start]; see [destroy] to tear
    it down. Stopping a worktree that has no window is a no-op.

USAGE

    ${LOCAL_USAGE[stop]}

ALIASES

    $(aliases_for LOCAL_ALIASES stop)

FLAGS

    -h, --help      display this message
help
}

function local::help::show() {
cat <<help
DESCRIPTION

    Opens the current worktree's local env window in a tmux popup that covers
    the current session, creating the window (w/o starting its services) if it
    doesn't exist yet.

    The popup attaches to the "dev" server, so it's a full tmux client: the
    panes can be navigated and typed in like any other. Close it w/ [hide], or
    by detaching.

USAGE

    ${LOCAL_USAGE[show]}

ALIASES

    $(aliases_for LOCAL_ALIASES show)

FLAGS

    -h, --help      display this message
help
}

function local::help::hide() {
cat <<help
DESCRIPTION

    Closes the local env popup by detaching every client attached to the "dev"
    server. Whatever is running in the popup keeps running.

USAGE

    ${LOCAL_USAGE[hide]}

ALIASES

    $(aliases_for LOCAL_ALIASES hide)

FLAGS

    -h, --help      display this message
help
}

function local::help::restart() {
cat <<help
DESCRIPTION

    Restarts the current worktree's services: [stop], then [start].

    Unlike [start], this doesn't create the window if it's missing, and doesn't
    stop the services of other worktrees.

USAGE

    ${LOCAL_USAGE[restart]}

ALIASES

    $(aliases_for LOCAL_ALIASES restart)

FLAGS

    -h, --help      display this message
help
}

function local::help::destroy() {
cat <<help
DESCRIPTION

    Stops the current worktree's services and kills its local env window. The
    worktree itself is untouched: see "dev worktree remove" to remove it.

    Warns and exits 0 if the worktree has no local env window.

USAGE

    ${LOCAL_USAGE[destroy]}

ALIASES

    $(aliases_for LOCAL_ALIASES destroy)

FLAGS

    -h, --help      display this message
help
}

function local::help::list() {
cat <<help
DESCRIPTION

    Lists, by name, the local env windows of the current session on the "dev"
    server. See "dev worktree list" to list worktrees instead, marked by whether
    they have a window.

USAGE

    ${LOCAL_USAGE[list]}

ALIASES

    $(aliases_for LOCAL_ALIASES list)

FLAGS

    -h, --help      display this message
help
}

## helpers #####################################################################

function __local::start() {
    dtmux send-keys -t "$(window::target)" 'just run-server' C-m
    dtmux send-keys -t "$(window::target 1)" 'pnpm start:subdomains' C-m
    dtmux send-keys -t "$(window::target 2)" 'just run-celery' C-m
}

function __local::stop_id() {
    local id="${1}"
    local i

    for i in 0 1 2; do
        dtmux send-keys -t "${id}.$((BASE_PANE_IDX+i))" C-c 'clear' C-m
    done
}

function __local::stop() {
    local id ; id="$(window::id "${1:-${WINDOW_NAME}}")"

    [[ -n "${id}" ]] || return 0
    __local::stop_id "${id}"
}

# Stops the services of every local env window but the current worktree's: they
# contend for the same ports.
function __local::stop_others() {
    local id
    local current ; current="$(window::id)"

    while IFS= read -r id; do
        [[ "${id}" == "${current}" ]] && continue
        __local::stop_id "${id}"
    done < <(dtmux list-windows -a -F '#{window_id}' 2> /dev/null)
}

## commands ####################################################################

function local::start() {
    window::exists || window::init_panes

    __local::stop_others
    __local::start
}

function local::stop() {
    __local::stop
}

function local::show() {
    window::exists || window::init_panes

    local id ; id="$(window::id)"

    tmux display-popup -E -w 99% -h 99% \
        "TMUX= TERM=screen-256color tmux -L ${DEV_SERVER} select-window -t '${id}' \; attach"
}

function local::hide() {
    dtmux detach-client
}

function local::restart() {
    __local::stop
    __local::start
}

function local::destroy() {
    local id ; id="$(window::id)"

    [[ -n "${id}" ]] || { ulogger warn "no dev window for '${WINDOW_NAME}'" ; return 0 ; }

    __local::stop_id "${id}"
    dtmux kill-window -t "${id}"
}

function local::list() {
    dtmux list-windows -F '#W' 2> /dev/null || return 0
}
