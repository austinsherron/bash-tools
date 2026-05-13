#!/usr/bin/env bash

source "${BASH_LIB}/args/validate.sh"


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
