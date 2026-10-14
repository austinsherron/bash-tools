#!/usr/bin/env bash


source "${BASH_LIB}/api/git.sh"
source "${BASH_LIB}/args/validate.sh"
source "${BASH_LIB}/log/utils.sh"
source "${BASH_LIB}/utils/input.sh"

source "${BASH_TOOLS}/tools/work/maybern/_helpers/window.sh"


# The "worktree" command group: the worktrees themselves, and the local env
# windows that belong to them.
#
# Worktrees are grouped into categories -- a category is a directory beneath the
# worktree root, and each worktree w/in it is a work item -- so a worktree is
# named by its "<category>/<item>" identifier throughout.
#
# This file holds what the group's commands share: their tables, the group's help
# message and the shared helpers. Each command -- its help message, its own helpers
# and its implementation -- lives in a file of its own beside it, named for it.

declare -A WT_CMDS=(
    [open]="open"
    [new]="new"
    [move]="move"
    [remove]="remove"
    [list]="list"
)

declare -A WT_DESCRIPTIONS=(
    [open]="open a local env window for an existing worktree"
    [new]="create a worktree in a category and open a local env window for it"
    [move]="move a worktree's window to another session, creating it if needed"
    [remove]="archive a worktree's session history, then remove the worktree and its branch"
    [list]="list the repo's worktrees, marking those w/ a local env window"
)

WT_GROUP_USAGE="dev worktree <cmd> [args] {flags}"

declare -A WT_USAGE=(
    [open]="dev worktree open"
    [new]="dev worktree new [-c category] [-x suffix] [-s start-point] [name]"
    [move]="dev worktree move [-c] [-s session] [category/item]"
    [remove]="dev worktree remove [-fnkwb] [category/item]"
    [list]="dev worktree list"
)

declare -A WT_ALIASES=(
    [o]=open
    [n]=new
    [add]=new
    [a]=new
    [create]=new
    [c]=new
    [mv]=move
    [m]=move
    [rm]=remove
    [delete]=remove
    [del]=remove
    [d]=remove
    [destroy]=remove
    [x]=remove
    [ls]=list
    [l]=list
)

## help ########################################################################

function wt::help() {
cat <<help
DESCRIPTION

    Manages worktrees and their local env windows.

    A category is a directory beneath the worktree root; the worktrees w/in it
    are work items, identified throughout by "<category>/<item>". Each category
    has a default worktree named after the category itself: the stable home for
    that category, which is never removed and which inherits the Claude session
    history of the ephemeral worktrees removed from it.

    Commands that act on a worktree take it as a "<category>/<item>" argument.
    W/out one, [move] acts on the current worktree, and picks one w/ fzf only
    when given -c|--choose; the others always pick one w/ fzf.

USAGE

    ${WT_GROUP_USAGE}

COMMANDS

$(cmd_descriptions WT_DESCRIPTIONS)

    run "dev worktree <cmd> -h" for a command's own help

ALIASES

    $(aliases_for GROUP_ALIASES worktree)

POSITIONAL ARGUMENTS

    CMD             the command to run

FLAGS

    -h, --help      display this message
help
}

## helpers #####################################################################

# Selects a worktree, by its "<category>/<item>" identifier, w/ fzf.
function __wt::select() {
    local prompt="${1:-worktree}"
    local skip="${2:-}"

    local rel
    local candidates=()

    while IFS= read -r rel; do
        [[ -n "${skip}" && "${rel}" == "${skip}" ]] && continue
        candidates+=("${rel}")
    done < <(git::list_worktrees -r)

    if [[ "${#candidates[@]}" -eq 0 ]]; then
        ulogger error "no worktrees to select" >&2
        return 1
    fi

    printf '%s\n' "${candidates[@]}" | fzf --ansi --tac --prompt="${prompt}> "
}

# Displays the worktree a command acts on, by its "<category>/<item>" identifier:
# the one given, the one picked w/ fzf when choosing, or else the current one.
# Empty when the fzf selection is cancelled.
# Arguments:
#   rel: optional; the worktree given on the command line
#   choose: optional; non-empty to pick the worktree w/ fzf
#   prompt: optional; the fzf prompt
function __wt::target() {
    local rel="${1:-}"
    local choose="${2:-}"
    local prompt="${3:-worktree}"

    if [[ -n "${rel}" && -n "${choose}" ]]; then
        ulogger error "a worktree and -c|--choose are mutually exclusive" >&2
        return 1
    fi

    if [[ -n "${rel}" ]]; then
        echo "${rel}"
    elif [[ -n "${choose}" ]]; then
        __wt::select "${prompt}"
    else
        git::worktree_rel
    fi
}

function __wt::resolve() {
    local rel="${1}"
    local path

    if ! path="$(git::worktree_for "${rel}")"; then
        ulogger error "no worktree '${rel}' in this repo" >&2
        return 1
    fi

    echo "${path}"
}

## commands ####################################################################

source "${BASH_TOOLS}/tools/work/maybern/cmd/worktree/open.sh"
source "${BASH_TOOLS}/tools/work/maybern/cmd/worktree/new.sh"
source "${BASH_TOOLS}/tools/work/maybern/cmd/worktree/move.sh"
source "${BASH_TOOLS}/tools/work/maybern/cmd/worktree/remove.sh"
source "${BASH_TOOLS}/tools/work/maybern/cmd/worktree/list.sh"
