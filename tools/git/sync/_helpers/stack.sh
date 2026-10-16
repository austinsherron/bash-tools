#!/usr/bin/env bash

source "${BASH_LIB}/api/git.sh"
source "${BASH_LIB}/utils/sys.sh"

source "${BASH_TOOLS}/tools/git/_helpers/stack.sh"
source "${BASH_TOOLS}/tools/git/_helpers/worktrees.sh"
source "${BASH_TOOLS}/tools/git/sync/_helpers/common.sh"


# Syncs a stack of branches (see: git/_helpers/stack.sh) w/ the source by rebasing its
# tip w/ "git rebase --update-refs", which moves every branch in the stack along
# w/ it.
#
# git won't move a branch that's checked out in another worktree, so each such
# branch is first "parked": its worktree is switched to a throwaway branch at the
# same commit, then switched back once the rebase is done.
#
# The throwaway branch is at the same commit, so parking never touches the
# worktree's files, and uncommitted changes simply stay put. Only switching back
# can run into them: git carries them onto the rebased branch unless the rebase
# changed the same files, in which case it refuses rather than overwrite them.

# the parked worktrees, as parallel arrays indexed by the order they were parked
__SYNC_PARKED_PATHS=()
__SYNC_PARKED_BRANCHES=()
__SYNC_PARKED_TMPS=()


#######################################
# Parks a worktree: switches it off the stack branch it has checked out, onto a
# throwaway branch named "__tmp-<worktree>-<id>" at the same commit.
# Arguments:
#   branch: the branch checked out in the worktree
#   path: the worktree's path
# Returns:
#   0 if the worktree was parked, 1 otherwise
#######################################
function __sync::park() {
    local branch="${1}"
    local path="${2}"

    local worktree tmp id
    worktree="$(git::worktree_rel "${path}")"

    id="$(sys::uuid)"
    tmp="__tmp-$(git::worktree_name "${path}")-${id:0:4}"

    if ! git -C "${path}" switch --quiet -c "${tmp}" > /dev/null 2>&1; then
        __sync::record_failure "failed to switch '${worktree}' off '${branch}' onto '${tmp}'"
        return 1
    fi

    __SYNC_PARKED_PATHS+=("${path}")
    __SYNC_PARKED_BRANCHES+=("${branch}")
    __SYNC_PARKED_TMPS+=("${tmp}")

    ulogger info "switched '${worktree}' from '${branch}' to '${tmp}'"
}

#######################################
# Switches a parked worktree back to its branch. When uncommitted changes block
# the switch, they're stashed around it w/ --force.
# Arguments:
#   branch: the branch to switch back to
#   path: the worktree's path
# Returns:
#   0 if the worktree was switched back, 1 otherwise
#######################################
function __sync::switch_back() {
    local branch="${1}"
    local path="${2}"
    local stashed=""

    git -C "${path}" switch --quiet "${branch}" > /dev/null 2>&1 && return 0

    # only uncommitted changes can be worked around, and only w/ --force
    [[ -n "${__SYNC_FORCE}" ]] && ! git::is_clean "${path}" || return 1
    __sync::stash_push "${branch}" "${path}" stashed || return 1

    if ! git -C "${path}" switch --quiet "${branch}" > /dev/null 2>&1; then
        __sync::stash_pop "${branch}" "${path}" "${stashed}" || true
        return 1
    fi

    __sync::stash_pop "${branch}" "${path}" "${stashed}" || true
}

#######################################
# Unparks a worktree: switches it back to its stack branch and deletes the
# throwaway branch. A worktree that can't be switched back is left on its
# throwaway branch, which is kept, and the commands to finish by hand are logged.
# Arguments:
#   i: the parked worktree's index
#######################################
function __sync::unpark() {
    local i="${1}"

    local path="${__SYNC_PARKED_PATHS[${i}]}"
    local branch="${__SYNC_PARKED_BRANCHES[${i}]}"
    local tmp="${__SYNC_PARKED_TMPS[${i}]}"

    local worktree ; worktree="$(git::worktree_rel "${path}")"

    if ! __sync::switch_back "${branch}" "${path}"; then
        __sync::record_failure "failed to switch '${worktree}' back to '${branch}'; it's left on '${tmp}'"

        if ! git::is_clean "${path}"; then
            ulogger error "its uncommitted changes overlap w/ the rebase; to finish by hand:"
            ulogger error "    cd ${path}"
            ulogger error "    git stash push -u && git switch ${branch} && git stash pop"
            ulogger error "    git branch -D ${tmp}"
        fi

        return 0
    fi

    git::delete_branch "${tmp}" -f > /dev/null 2>&1 || \
        ulogger warn "failed to delete throwaway branch '${tmp}'"

    ulogger info "switched '${worktree}' back to '${branch}'"
    return 0
}

#######################################
# Unparks every parked worktree, most recently parked first. Exits are deferred
# until every worktree has been restored.
#######################################
function __sync::unpark_all() {
    local i

    __SYNC_DEFER_EXIT="true"

    for (( i = ${#__SYNC_PARKED_PATHS[@]} - 1; i >= 0; i-- )); do
        __sync::unpark "${i}"
    done

    __SYNC_PARKED_PATHS=()
    __SYNC_PARKED_BRANCHES=()
    __SYNC_PARKED_TMPS=()

    __SYNC_DEFER_EXIT=""
}

#######################################
# Parks the worktree of every stack branch below the tip that's checked out.
# Arguments:
#   tip: the tip of the stack
#   stack: the stack's branches
# Returns:
#   0 if every checked-out branch was parked, 1 otherwise
#######################################
function __sync::park_stack() {
    local tip="${1}" ; shift
    local branch path

    for branch in "$@"; do
        [[ "${branch}" = "${tip}" ]] && continue

        worktrees::path_for "${branch}" path
        [[ -z "${path}" ]] && continue

        __sync::park "${branch}" "${path}" || return 1
    done
}

function __sync::rebase_stack() {
    __sync::run "${1}" "${2}" --update-refs
}

#######################################
# Syncs a stack of branches w/ the source by rebasing its tip onto the source w/
# "git rebase --update-refs". The rebase runs in place if the tip is checked out,
# and in a throwaway worktree otherwise.
#
# W/ -u, only the part of the stack above <upstream> is rebased, onto the source.
# This propagates new commits in a branch w/in a stack (the source) up to the
# branches built on it, w/ <upstream> being the commit they were built on.
#
# Every other stack branch that's checked out is parked for the rebase (see:
# __sync::park) and restored afterward, uncommitted changes and all. If any can't
# be parked, the stack isn't rebased at all: git would leave that branch behind,
# splitting the stack.
# Arguments:
#   tip: the tip of the stack
#   -o, -u, -f, -s: the sync options (see: __sync::configure)
#######################################
function sync::stack() {
    local tip="${1}" ; shift
    local stack=()
    local path

    __sync::configure "$@" || return 1
    __SYNC_MODE="rebase"

    stack::branches "${tip}" "${__SYNC_UPSTREAM:-${__SYNC_SOURCE}}" stack

    if [[ ${#stack[@]} -eq 0 ]]; then
        ulogger info "no branches in the stack below '${tip}'"
        return 0
    fi

    if [[ -n "${__SYNC_UPSTREAM}" ]]; then
        ulogger info "propagating '${__SYNC_SOURCE}' up the stack: ${stack[*]}"
    else
        ulogger info "rebasing stack onto '${__SYNC_SOURCE}': ${stack[*]}"
    fi

    if __sync::park_stack "${tip}" "${stack[@]}"; then
        worktrees::path_for "${tip}" path

        if [[ -n "${path}" ]]; then
            __sync::in_place "${tip}" "${path}" __sync::rebase_stack
        else
            __sync::in_tmp_worktree "${tip}" __sync::rebase_stack
        fi
    else
        __sync::record_failure "not rebasing the stack: a branch in it couldn't be switched out"
    fi

    __sync::unpark_all

    if [[ -n "${__SYNC_STRICT}" ]] && sync::has_failures; then
        exit 1
    fi
}
