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
# Displays the root path of the main/primary repository.
# Outputs:
#   Writes to stdout the root path of the main repository
#######################################
function git::root() {
    local -r common_dir="$(git rev-parse --git-common-dir)"
    dirname "$(realpath "${common_dir}")"
}

#######################################
# Displays the path of the active worktree.
# Outputs:
#   Writes to stdout the path of the active worktree
#######################################
function git::worktree() {
    git rev-parse --show-toplevel
}
