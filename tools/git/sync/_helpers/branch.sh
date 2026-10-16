#!/usr/bin/env bash

source "${BASH_LIB}/api/git.sh"

source "${BASH_TOOLS}/tools/git/_helpers/worktrees.sh"
source "${BASH_TOOLS}/tools/git/sync/_helpers/common.sh"


# Syncs a single branch w/ the source: by fast-forward where possible, and by
# merge or rebase (per the sync mode) otherwise.


function __sync::do_fast_forward() {
    local branch="${1}"
    local path="${2}"

    if git -C "${path}" merge --ff-only "${__SYNC_SOURCE}" > /dev/null 2>&1; then
        ulogger info "synced '${branch}' <- '${__SYNC_SOURCE}' (fast-forward)"
        return 0
    fi

    __sync::fail "failed to fast-forward '${branch}' to '${__SYNC_SOURCE}'"
}

function __sync::fast_forward() {
    local branch="${1}"
    local path="${2:-}"

    if [[ -n "${path}" ]]; then
        # git refuses to self-fetch into a checked-out branch, so fast-forward in
        # place; --ff-only guarantees no merge commit regardless of mode
        __sync::in_place "${branch}" "${path}" __sync::do_fast_forward
        return 0
    fi

    # a local "self-fetch" moves the ref w/out a worktree or working tree
    if git fetch --quiet . "${__SYNC_SOURCE}:${branch}" > /dev/null 2>&1; then
        ulogger info "synced '${branch}' <- '${__SYNC_SOURCE}' (fast-forward)"
        return 0
    fi

    __sync::fail "failed to fast-forward '${branch}' to '${__SYNC_SOURCE}'"
}

#######################################
# Syncs a branch w/ the source, w/out switching the branch checked out in any
# worktree. A branch that can be fast-forwarded always is; one that can't is
# merged or rebased per the sync mode, in place if it's checked out, and in a
# throwaway worktree otherwise.
# Arguments:
#   branch: the branch to sync
#   -o, -m, -f, -s: the sync options (see: __sync::configure)
#######################################
function sync::branch() {
    local branch="${1}" ; shift
    local path

    __sync::configure "$@" || return 1
    worktrees::path_for "${branch}" path

    # always prefer a fast-forward, whether or not the branch is checked out
    if git::can_fast_forward "${branch}" -s "${__SYNC_SOURCE}"; then
        __sync::fast_forward "${branch}" "${path}"
    elif [[ -n "${path}" ]]; then
        # diverged checked-out branches must be synced in place; git refuses to
        # fetch into them
        __sync::in_place "${branch}" "${path}" __sync::run
    else
        __sync::in_tmp_worktree "${branch}" __sync::run
    fi
}
