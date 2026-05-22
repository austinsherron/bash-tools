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
#   -n: If provided, display worktree names, instead of paths
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
