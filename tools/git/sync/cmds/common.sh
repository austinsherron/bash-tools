#!/usr/bin/env bash

source "${BASH_LIB}/args/validate.sh"
source "${BASH_LIB}/api/git.sh"

source "${BASH_TOOLS}/tools/git/_helpers/config.sh"
source "${BASH_TOOLS}/tools/git/_helpers/view.sh"
source "${BASH_TOOLS}/tools/git/_helpers/worktrees.sh"


# Validation and output shared by the git-sync sub-commands.


function sync_cmds::validate_in_repo() {
    if ! git::in_repo; then
        ulogger error "not inside a git repository"
        exit 1
    fi
}

#######################################
# Exits w/ rc=1 if a branch doesn't exist.
# Arguments:
#   branch: the branch to check
#   type: optional; a word describing the branch in the error (e.g. "source")
#######################################
function sync_cmds::validate_branch_exists() {
    local branch="${1}"
    local type="${2:-}"

    [[ -n "${type}" ]] && type="${type} "

    if ! git::branch_exists "${branch}"; then
        ulogger error "${type}branch '${branch}' does not exist"
        exit 1
    fi
}

#######################################
# Resolves the branch a stack operation starts from: the given branch, if any, and
# the current branch otherwise. Exits w/ rc=1 if HEAD is detached.
# Arguments:
#   branch: the branch given, or ""
#   out: the name of the variable to assign the branch to
#######################################
function sync_cmds::start_branch() {
    local -n __sync_cmds_start_out="${2}"
    __sync_cmds_start_out="${1}"

    [[ -n "${__sync_cmds_start_out}" ]] && return 0

    if ! __sync_cmds_start_out="$(git::current_branch)" ||
        [[ -z "${__sync_cmds_start_out}" ]]; then
        ulogger error "HEAD is detached; use -b|--branch to name a branch in the stack"
        exit 1
    fi
}

#######################################
# Exits w/ rc=1 if -i|--interactive can't prompt: when stdin isn't a terminal, or
# w/ -c|--check, whose output is meant for scripts.
# Arguments:
#   interactive: non-empty if -i|--interactive was given
#   check: non-empty if -c|--check was given
#######################################
function sync_cmds::validate_interactive() {
    local interactive="${1}"
    local check="${2}"

    [[ -n "${interactive}" ]] || return 0

    validate_mutually_exclusive \
        "${interactive}" "-i|--interactive" "${check}" "-c|--check" || exit 1

    if [[ ! -t 0 ]]; then
        ulogger error "-i|--interactive requires a terminal"
        exit 1
    fi
}

#######################################
# Prompts for confirmation, which defaults to yes.
# Arguments:
#   prompt: optional, defaults to "Proceed?"; the prompt
# Returns:
#   0 if confirmed, 1 otherwise
#######################################
function sync_cmds::confirm() {
    local prompt="${1:-Proceed?}"
    local reply=""

    echo
    read -r -p "${prompt} [Y/n] " reply || { echo ; return 1 ; }

    [[ -z "${reply}" || "${reply}" =~ ^[Yy]([Ee][Ss])?$ ]]
}

#######################################
# Styles a branch for display (see: view::style_branch), padded to a width so that
# columns of styled branches line up.
# Arguments:
#   branch: the branch to style
#   width: optional, defaults to 0; the width to pad the branch to
#######################################
function sync_cmds::style_branch() {
    local branch="${1}"
    local width="${2:-0}"
    local category path

    worktrees::category_for "${branch}" category
    worktrees::path_for "${branch}" path

    view::style_branch "$(printf '%-*s' "${width}" "${branch}")" "${category}" "${path}"
}

#######################################
# Displays the length of the longest of the given strings.
# Arguments:
#   strs: the strings to measure
#######################################
function sync_cmds::max_width() {
    local width=0
    local str

    for str in "$@"; do
        [[ ${#str} -gt ${width} ]] && width=${#str}
    done

    echo "${width}"
}

#######################################
# Describes where a branch is checked out, for display.
# Arguments:
#   branch: the branch to describe
#   out: the name of the variable to assign the description to; "" if the branch
#        isn't checked out
#   path_out: optional; the name of the variable to assign the worktree's path to
#######################################
function sync_cmds::worktree_of() {
    local branch="${1}"
    local -n __sync_cmds_wt_out="${2}"
    local __sync_cmds_wt_path

    worktrees::path_for "${branch}" __sync_cmds_wt_path

    __sync_cmds_wt_out=""
    [[ -n "${__sync_cmds_wt_path}" ]] &&
        __sync_cmds_wt_out="in '$(git::worktree_rel "${__sync_cmds_wt_path}")'"

    if [[ -n "${3:-}" ]]; then
        local -n __sync_cmds_wt_path_out="${3}"
        __sync_cmds_wt_path_out="${__sync_cmds_wt_path}"
    fi

    return 0
}

function _sync_cmds::print_group() {
    [[ $# -gt 0 ]] && printf '%s\n' "$@"
    return 0
}

#######################################
# Writes the branches a sync would update to stdout: configured default branches
# first, then the rest.
# Arguments:
#   branches: the branches the sync would update
# Returns:
#   0 if no branches would be updated, 1 otherwise
#######################################
function sync_cmds::check() {
    [[ $# -eq 0 ]] && return 0

    local defaults=()
    local others=()
    local branch out

    for branch in "$@"; do
        out="$(sync_cmds::style_branch "${branch}")"

        if config::is_default_branch "${branch}"; then
            defaults+=("${out}")
        else
            others+=("${out}")
        fi
    done

    # defaults first, then other branches; alphanumeric within each group
    _sync_cmds::print_group ${defaults[@]+"${defaults[@]}"}
    _sync_cmds::print_group ${others[@]+"${others[@]}"}

    return 1
}
