#!/usr/bin/env bash

source "${BASH_LIB}/args/validate.sh"
source "${BASH_LIB}/core/_shared.sh"


validate_installed git.sh git

#######################################
# Checks if the current directory is inside a git repo.
# Returns:
#   0 if inside a git repo, 1 otherwise
#######################################
function git::in_repo() {
    git rev-parse --is-inside-work-tree &> /dev/null
}

#######################################
# Checks if the current (or provided) git repo has uncommitted changes.
# Arguments:
#   -u: ignore untracked files; only consider changes to tracked files
#   dir: optional, defaults to current repo; the repo to check
# Returns:
#   0 if the repo has no uncommitted changes, 1 otherwise
#######################################
function git::is_clean() {
    local untracked="normal"

    local OPTIND=1
    while getopts "u" opt; do
      case $opt in
        u) untracked="no" ;;
        \?) ulogger error "valid flags are -u" >&2 ; return 1 ;;
      esac
    done
    shift $((OPTIND - 1))

    local dir="${1:-}"
    local args=(status --porcelain "--untracked-files=${untracked}")

    [[ -n "${dir}" ]] && args=(-C "$(realpath "${dir}")" "${args[@]}")
    [[ -z "$(git "${args[@]}")" ]]
}

#######################################
# Checks whether one ref is an ancestor of another, i.e.: whether the descendant
# already contains every commit reachable from the ancestor.
# Arguments:
#   ancestor:   the ref that may be contained (e.g. "master")
#   descendant: the ref that may contain the ancestor
# Returns:
#   0 if ancestor is an ancestor of descendant, 1 otherwise
#######################################
function git::is_ancestor() {
    git merge-base --is-ancestor "${1}" "${2}"
}

#######################################
# Checks if a branch can be fast-forwarded (based on a source branch).
# Arguments:
#   branch: the branch to check
#   -s: optional, defaults to master; the source branch
# Returns:
#   0 if branch can be fast-forwarded, 1 otherwise
#######################################
function git::can_fast_forward() {
    local branch="${1}" ; shift
    local source="master"

    local OPTIND=1
    while getopts "s:" opt; do
      case $opt in
        s) source="${OPTARG}" ;;
        \?) ulogger error "valid flags are -s" >&2 ; return 1 ;;
      esac
    done
    shift $((OPTIND - 1))

    git::is_ancestor "${branch}" "${source}"
}

#######################################
# Displays the root path of the repo/primary worktree.
# Outputs:
#   Writes to stdout the root path of the main repository
#######################################
function git::root() {
    dirname "$(git rev-parse --path-format=absolute --git-common-dir)"
}

#######################################
# Displays the name of the current repo.
# Outputs:
#   Writes to stdout the basename of the current repo.
#######################################
function git::repo_name() {
    basename "$(git::root)"
}

#######################################
# Checks if a branch w/ the provided name exists in the current repo.
# Arguments:
#   branch: the name of the branch to check
# Returns:
#   0 if a branch w/ the provided name exists in the current repo, 1 otherwise
#######################################
function git::branch_exists() {
    local branch="${1}"
    git show-ref --verify --quiet "refs/heads/${branch}"
}

#######################################
# Checks if the current directory is in a worktree associated w/ the provided repo.
# Arguments:
#   repo: the name of the repo to check.
# Returns:
#   0 if the current directory is in a worktree repo, 1 otherwise
#######################################
function git::in_repo_worktree() {
    local repo="${1}"
    local worktree_repo

    git::in_repo || return 1
    worktree_repo="$(basename "$(dirname "$(git rev-parse --git-common-dir)")")"

    [[ "${repo}" = "${worktree_repo}" ]]
}

#######################################
# Displays the worktree parent directory.
# Outputs:
#   Writes the worktree parent directory to stdout.
#######################################
function git::worktree_root() {
    dirname "$(git::root)"
}

#######################################
# Displays the path of the active worktree.
# Outputs:
#   Writes to stdout the path of the active worktree
#######################################
function git::worktree() {
    git rev-parse --show-toplevel
}

#######################################
# Displays the name of the active worktree.
# Outputs:
#   Writes to stdout the name of the active worktree
#######################################
function git::worktree_name() {
    basename "$(git::worktree)"
}

#######################################
# Checks if the current repo uses worktrees.
#
# A repo is considered to use worktrees if it has > 1 worktree.
# Returns:
#   0 if the current repo uses worktrees, 1 otherwise 
#######################################
function git::uses_worktrees() {
    local worktree_count
    worktree_count="$(git worktree list | wc -l)"

    [[ "${worktree_count}" -gt 1 ]]
}

#######################################
# Displays the current repo's worktrees.
# Arguments:
#   -n: if provided, display worktree names, instead of paths
# Outputs:
#   Writes to stdout the current repo's worktrees
#######################################
function git::list_worktrees() {
    local name_only=""

    local OPTIND=1
    while getopts "n" opt; do
      case $opt in
        n) name_only="true" ;;
        \?) ulogger error "valid flags are -n" >&2 ; return 1 ;;
      esac
    done
    shift $((OPTIND - 1))

    if [[ -z "${name_only}" ]]; then
        git worktree list | awk '{print $1}'
    else
        git worktree list | awk '{print $1}' | xargs basename
    fi
}
