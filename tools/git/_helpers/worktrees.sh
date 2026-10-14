#!/usr/bin/env bash

source "${BASH_LIB}/api/git.sh"


declare -A __WORKTREE_NAME_BY_BRANCH       # branch (short) -> worktree name (item)
declare -A __WORKTREE_PATH_BY_BRANCH       # branch (short) -> worktree path
declare -A __WORKTREE_REL_BY_BRANCH        # branch (short) -> "<category>/<item>"
declare -A __WORKTREE_CATEGORY_BY_BRANCH   # branch (short) -> category
declare -A __WORKTREE_CATEGORIES           # set of categories in use

__WORKTREE_CURRENT=""                      # the active worktree's path
__WORKTREES_LOADED=""


#######################################
# Re-keys the repo's worktree listing by branch. git::worktree_paths loads that
# listing with a single "git worktree list", and the lookups below are pure map
# reads, so this costs one git invocation per process.
#######################################
function __worktrees::init() {
    [[ -n "${__WORKTREES_LOADED}" ]] && return 0
    __WORKTREES_LOADED="true"

    local paths=()
    local path branch rel category

    __WORKTREE_CURRENT="$(git::worktree)"

    git::worktree_paths paths
    [[ ${#paths[@]} -eq 0 ]] && return 0

    for path in "${paths[@]}"; do
        rel="$(git::worktree_rel "${path}")"
        category="${rel%%/*}"

        # a category is recorded for every worktree, checked out or detached, so
        # that per-category config (indicators, colors) covers the whole repo.
        # An empty subscript is a hard error in bash, so a worktree that resolves
        # to no category is skipped rather than taking the caller down w/ it
        [[ -n "${category}" ]] && __WORKTREE_CATEGORIES["${category}"]="true"

        branch="$(git::worktree_branch "${path}")"
        [[ -z "${branch}" ]] && continue

        __WORKTREE_NAME_BY_BRANCH["${branch}"]="${path##*/}"
        __WORKTREE_PATH_BY_BRANCH["${branch}"]="${path}"
        __WORKTREE_REL_BY_BRANCH["${branch}"]="${rel}"
        __WORKTREE_CATEGORY_BY_BRANCH["${branch}"]="${category}"
    done

    return 0
}

#######################################
# Returns a looked-up value, either by assigning it to a caller-named variable or,
# when no name is given, by writing it to stdout.
#
# Passing a variable is preferred in a loop. The cache above is built on the first
# lookup, so a first lookup made inside "$(...)" builds it in a subshell that then
# discards it, and every later lookup rebuilds it from scratch.
# Arguments:
#   value: the value to return
#   out: optional; the name of the variable to assign the value to
#######################################
function __worktrees::return() {
    local __wt_value="${1}"
    local __wt_out="${2:-}"

    if [[ -z "${__wt_out}" ]]; then
        echo "${__wt_value}"
        return 0
    fi

    local -n __wt_ref="${__wt_out}"
    __wt_ref="${__wt_value}"
}

#######################################
# Displays the name (i.e.: the "work item") of the worktree a branch is checked
# out in, or nothing if it isn't checked out anywhere.
# Arguments:
#   branch: the branch to look up
#   out: optional; the name of the variable to assign the result to
#######################################
function worktrees::name_for() {
    __worktrees::init
    __worktrees::return "${__WORKTREE_NAME_BY_BRANCH[${1}]:-}" "${2:-}"
}

#######################################
# Displays the path of the worktree a branch is checked out in, or nothing if it
# isn't checked out anywhere.
# Arguments:
#   branch: the branch to look up
#   out: optional; the name of the variable to assign the result to
#######################################
function worktrees::path_for() {
    __worktrees::init
    __worktrees::return "${__WORKTREE_PATH_BY_BRANCH[${1}]:-}" "${2:-}"
}

#######################################
# Displays the "<category>/<item>" identifier of the worktree a branch is checked
# out in, or nothing if it isn't checked out anywhere.
# Arguments:
#   branch: the branch to look up
#   out: optional; the name of the variable to assign the result to
#######################################
function worktrees::rel_for() {
    __worktrees::init
    __worktrees::return "${__WORKTREE_REL_BY_BRANCH[${1}]:-}" "${2:-}"
}

#######################################
# Displays the category of the worktree a branch is checked out in, or nothing if
# it isn't checked out anywhere.
# Arguments:
#   branch: the branch to look up
#   out: optional; the name of the variable to assign the result to
#######################################
function worktrees::category_for() {
    __worktrees::init
    __worktrees::return "${__WORKTREE_CATEGORY_BY_BRANCH[${1}]:-}" "${2:-}"
}

#######################################
# Copies the categories in use by the repo's worktrees into the caller's array.
# Arguments:
#   out: the name of the array to populate
#######################################
function worktrees::categories() {
    __worktrees::init
    local -n out="${1}"
    out=("${!__WORKTREE_CATEGORIES[@]}")
}

#######################################
# Checks whether a worktree path is the active worktree.
# Arguments:
#   path: the worktree path to check
# Returns:
#   0 if the path is the active worktree, 1 otherwise
#######################################
function worktrees::is_current() {
    local path="${1}"

    __worktrees::init

    [[ -n "${path}" ]] || return 1
    [[ "${path%/}" = "${__WORKTREE_CURRENT}" ]]
}
