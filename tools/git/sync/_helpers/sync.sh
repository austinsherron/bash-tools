#!/usr/bin/env bash

source "${BASH_TOOLS}/tools/git/sync/_helpers/common.sh"
source "${BASH_TOOLS}/tools/git/sync/_helpers/branch.sh"
source "${BASH_TOOLS}/tools/git/sync/_helpers/stack.sh"


#######################################
# Restores whatever a sync operation left behind: parked worktrees are switched
# back to their branches, and throwaway worktrees are removed. Meant to run on
# exit, so an interrupted sync doesn't strand either.
#######################################
function sync::cleanup() {
    __sync::unpark_all
    __sync::cleanup_tmp_worktrees
    __sync::cleanup_tmp_root
}
