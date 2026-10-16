#!/usr/bin/env bash

source "${BASH_LIB}/api/git.sh"


# State and building blocks shared by the sync operations in this directory:
# option handling, failure reporting, stashing, and throwaway worktrees.

__SYNC_SOURCE="master"
__SYNC_MODE="ff"
__SYNC_UPSTREAM=""
__SYNC_FORCE=""
__SYNC_STRICT=""

__SYNC_TEMP_WORKTREES=()
__SYNC_TMP_ROOT=""
__SYNC_FAILURES=0

# set while restoring state (i.e.: on exit), when a --strict exit would leave the
# rest of that state unrestored
__SYNC_DEFER_EXIT=""


## options #####################################################################

#######################################
# Sets the options that govern a sync operation.
# Arguments:
#   -o: the branch to sync from
#   -m: the sync mode ("fast-forward", "merge" or "rebase")
#   -u: optional; w/ rebase, the commit after which commits are replayed onto the
#       source (i.e.: "git rebase --onto <source> <upstream>"); defaults to the
#       source itself
#   -f: non-empty to stash uncommitted changes rather than skip the branch
#   -s: non-empty to exit w/ rc=1 on the first failure
#######################################
function __sync::configure() {
    local OPTIND=1

    __SYNC_UPSTREAM=""

    while getopts "o:m:u:f:s:" opt; do
      case $opt in
        o) __SYNC_SOURCE="${OPTARG}" ;;
        m) __SYNC_MODE="${OPTARG}" ;;
        u) __SYNC_UPSTREAM="${OPTARG}" ;;
        f) __SYNC_FORCE="${OPTARG}" ;;
        s) __SYNC_STRICT="${OPTARG}" ;;
        :) ulogger error "arg required for -omufs" >&2 ; return 1 ;;
        \?) ulogger error "valid flags are -omufs" >&2 ; return 1 ;;
      esac
    done
}

## failures ####################################################################

#######################################
# Logs an error and counts it as a failure, w/out exiting.
# Arguments:
#   msg: the error to log
#######################################
function __sync::record_failure() {
    ulogger error "${1}"
    __SYNC_FAILURES=$((__SYNC_FAILURES + 1))
}

#######################################
# Logs an error and counts it as a failure. With --strict, exits w/ rc=1 unless
# exits are deferred.
# Arguments:
#   msg: the error to log
#######################################
function __sync::fail() {
    __sync::record_failure "${1}"
    [[ -n "${__SYNC_STRICT}" && -z "${__SYNC_DEFER_EXIT}" ]] && exit 1

    return 0
}

#######################################
# Logs a warning for a recoverable problem (e.g. a merge conflict). With --strict
# the problem is instead treated as a hard failure via __sync::fail.
# Arguments:
#   msg: the problem to report
# Returns:
#   0 if only a warning was logged, 1 otherwise
#######################################
function __sync::warn_or_fail() {
    local msg="${1}"

    if [[ -n "${__SYNC_STRICT}" ]]; then
        __sync::fail "${msg}"
        return 1
    fi

    ulogger warn "${msg}"
    return 0
}

## stashing ####################################################################

# The stash list is shared by every worktree of a repo, and others (e.g. another
# session in another worktree) may push to it concurrently, so a stash is only
# ever referred to by its commit, never by its position (e.g. "stash@{0}").

#######################################
# Finds a stash by its message.
# Arguments:
#   path: a worktree of the repo
#   name: the stash's message
# Outputs:
#   Writes the stash's commit to stdout, or nothing if no stash matches
#######################################
function __sync::stash_find() {
    local path="${1}"
    local name="${2}"
    local sha subject

    # a stash's subject is "On <branch>: <message>"
    while read -r sha subject; do
        [[ "${subject}" = *": ${name}" ]] && echo "${sha}" && return 0
    done < <(git -C "${path}" stash list --format='%H %gs')

    return 0
}

#######################################
# Drops a stash by its commit, wherever it now sits in the stash list.
# Arguments:
#   path: a worktree of the repo
#   sha: the stash's commit
#######################################
function __sync::stash_drop() {
    local path="${1}"
    local sha="${2}"
    local ref s

    while read -r ref s; do
        if [[ "${s}" = "${sha}" ]]; then
            git -C "${path}" stash drop --quiet "${ref}" > /dev/null 2>&1 || true
            return 0
        fi
    done < <(git -C "${path}" stash list --format='%gd %H')
}

#######################################
# Stashes the uncommitted changes in a worktree, including untracked files. The
# preceding "git add" ensures untracked files are captured by the stash.
# Arguments:
#   branch: the branch checked out in the worktree
#   path: the worktree's path
#   out: the name of the variable to assign the stash's commit to
# Returns:
#   0 if the changes were stashed, 1 otherwise
#######################################
function __sync::stash_push() {
    local branch="${1}"
    local path="${2}"
    local -n __sync_stash_out="${3}"

    local worktree
    local name

    worktree="$(git::worktree_rel "${path}")"
    name="sync-${worktree} @ $(date '+%Y-%m-%dT%H:%M:%S') ($$)"

    git -C "${path}" add -A > /dev/null 2>&1 || true

    if git -C "${path}" stash push -m "${name}" > /dev/null 2>&1 &&
        __sync_stash_out="$(__sync::stash_find "${path}" "${name}")" &&
        [[ -n "${__sync_stash_out}" ]]; then
        ulogger info "stashed changes in '${worktree}' (branch '${branch}') as '${name}'"
        return 0
    fi

    __sync::fail "failed to stash changes in worktree '${worktree}' (branch '${branch}')"
    return 1
}

#######################################
# Re-applies a stash onto a worktree and always drops it from the stash list, even
# when it applies w/ conflicts.
# Arguments:
#   branch: the branch checked out in the worktree
#   path: the worktree's path
#   sha: the stash's commit
#######################################
function __sync::stash_pop() {
    local branch="${1}"
    local path="${2}"
    local sha="${3}"
    local worktree
    worktree="$(git::worktree_rel "${path}")"

    if git -C "${path}" stash apply "${sha}" > /dev/null 2>&1; then
        __sync::stash_drop "${path}" "${sha}"
        ulogger info "re-applied stashed changes to '${worktree}' (branch '${branch}')"
        return 0
    fi

    # drop regardless: the stash must never linger in the stash list
    __sync::stash_drop "${path}" "${sha}"
    __sync::warn_or_fail "stashed changes could not be re-applied cleanly to '${worktree}' (branch '${branch}')"
}

#######################################
# Clears a worktree of uncommitted changes, if it has any: they're stashed w/
# --force, and the worktree is refused otherwise.
# Arguments:
#   branch: the branch checked out in the worktree
#   path: the worktree's path
#   out: the name of the variable to assign the stash's commit to, if changes were
#        stashed
# Returns:
#   0 if the worktree is now clean, 1 otherwise
#######################################
function __sync::clear_changes() {
    local branch="${1}"
    local path="${2}"
    local -n __sync_stashed_out="${3}"

    __sync_stashed_out=""
    git::is_clean "${path}" && return 0

    if [[ -z "${__SYNC_FORCE}" ]]; then
        __sync::fail "worktree '$(git::worktree_rel "${path}")' (branch '${branch}') has uncommitted changes; skipping"
        return 1
    fi

    __sync::stash_push "${branch}" "${path}" "${3}"
}

#######################################
# Runs an in-place sync (sync_fn) w/in a checked-out worktree, handling
# uncommitted changes: skip (default) or stash-sync-restore (--force).
# Arguments:
#   branch: the branch checked out in the worktree
#   path: the worktree's path
#   sync_fn: the function to run, as "sync_fn <branch> <path>"
#######################################
function __sync::in_place() {
    local branch="${1}"
    local path="${2}"
    local sync_fn="${3}"
    local stashed

    __sync::clear_changes "${branch}" "${path}" stashed || return 0

    "${sync_fn}" "${branch}" "${path}"
    [[ -n "${stashed}" ]] && __sync::stash_pop "${branch}" "${path}" "${stashed}"

    return 0
}

## sync ########################################################################

#######################################
# Merges or rebases the source into the branch checked out in a worktree, per the
# sync mode. A sync that can't complete cleanly is aborted.
# Arguments:
#   branch: the branch checked out in the worktree
#   path: the worktree's path
#   args: optional; extra args for the underlying merge or rebase
#######################################
function __sync::run() {
    local branch="${1}" ; shift
    local path="${1}" ; shift
    local op cmd=()
    local upstream=("${__SYNC_SOURCE}")

    [[ -n "${__SYNC_UPSTREAM}" ]] && upstream=(--onto "${__SYNC_SOURCE}" "${__SYNC_UPSTREAM}")

    case "${__SYNC_MODE}" in
        merge)  op="merge"  ; cmd=(merge --no-edit "$@" "${__SYNC_SOURCE}") ;;
        rebase) op="rebase" ; cmd=(rebase "$@" "${upstream[@]}") ;;
    esac

    if git -C "${path}" "${cmd[@]}" > /dev/null 2>&1; then
        ulogger info "synced '${branch}' <- '${__SYNC_SOURCE}' (${__SYNC_MODE})"
        return 0
    fi

    git -C "${path}" "${op}" --abort > /dev/null 2>&1 || true
    # __sync::warn_or_fail returns 0 (warns and continues) unless --strict, which
    # exits; keeping it non-zero-free avoids tripping set -e in bare-statement
    # callers
    __sync::warn_or_fail "'${branch}' cannot be synced cleanly w/ '${__SYNC_SOURCE}' via ${__SYNC_MODE}; skipping"
}

## throwaway worktrees #########################################################

#######################################
# Runs a sync (sync_fn) on a branch that isn't checked out anywhere, w/in a
# throwaway worktree that's removed afterward.
# Arguments:
#   branch: the branch to sync
#   sync_fn: the function to run, as "sync_fn <branch> <path>"
#######################################
function __sync::in_tmp_worktree() {
    local branch="${1}"
    local sync_fn="${2}"

    if [[ -z "${__SYNC_TMP_ROOT}" ]]; then
        __SYNC_TMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/git-sync.XXXXXX")"
    fi

    local tmp="${__SYNC_TMP_ROOT}/${branch//\//_}"

    if ! git worktree add --quiet "${tmp}" "${branch}" > /dev/null 2>&1; then
        __sync::fail "failed to create temporary worktree for branch '${branch}'"
        return 0
    fi

    __SYNC_TEMP_WORKTREES+=("${tmp}")
    "${sync_fn}" "${branch}" "${tmp}"

    git worktree remove --force "${tmp}" > /dev/null 2>&1 || true
}

function __sync::cleanup_tmp_worktrees() {
    [[ ${#__SYNC_TEMP_WORKTREES[@]} -eq 0 ]] && return 0

    local wt
    for wt in "${__SYNC_TEMP_WORKTREES[@]}"; do
        [[ -d "${wt}" ]] && git worktree remove --force "${wt}" > /dev/null 2>&1 || true
    done
}

function __sync::cleanup_tmp_root() {
    if [[ -n "${__SYNC_TMP_ROOT}" && -d "${__SYNC_TMP_ROOT}" ]]; then
        rm -rf "${__SYNC_TMP_ROOT}" 2>/dev/null || true
    fi
}

## public ######################################################################

#######################################
# Checks whether any sync operation has failed.
# Returns:
#   0 if any sync operation failed, 1 otherwise
#######################################
function sync::has_failures() {
    [[ "${__SYNC_FAILURES}" -ne 0 ]]
}
