#!/usr/bin/env bash

source "${BASH_LIB}/api/git.sh"

source "${BASH_TOOLS}/tools/git/_helpers/worktrees.sh"


__SYNC_SOURCE="master"
__SYNC_MODE="ff"
__SYNC_FORCE=""
__SYNC_STRICT=""

__SYNC_TEMP_WORKTREES=()
__SYNC_TMP_ROOT=""
__SYNC_FAILURES=0


function _fail() {
    ulogger error "${1}"

    __SYNC_FAILURES=$((__SYNC_FAILURES + 1))
    [[ -n "${__SYNC_STRICT}" ]] && exit 1

    return 0
}

# Logs a warning for a recoverable problem (e.g. a merge conflict). With
# --strict the problem is instead treated as a hard failure via _fail.
function _warn_or_fail() {
    local msg="${1}"

    if [[ -n "${__SYNC_STRICT}" ]]; then
        _fail "${msg}"      # logs an error and, under --strict, exits 1
        return 1
    fi

    ulogger warn "${msg}"
    return 0
}

function _run_sync() {
    local branch="${1}"
    local path="${2}"
    local cmd=()

    case "${__SYNC_MODE}" in
        merge)  cmd=(merge --no-edit "${__SYNC_SOURCE}") ;;
        rebase) cmd=(rebase "${__SYNC_SOURCE}") ;;
    esac

    if git -C "${path}" "${cmd[@]}" > /dev/null 2>&1; then
        ulogger info "synced '${branch}' <- '${__SYNC_SOURCE}' (${__SYNC_MODE})"
        return 0
    fi

    git -C "${path}" "${__SYNC_MODE}" --abort > /dev/null 2>&1 || true
    # _warn_or_fail returns 0 (warns and continues) unless --strict, which exits;
    # keeping it non-zero-free avoids tripping set -e in bare-statement callers
    _warn_or_fail "'${branch}' cannot be synced cleanly with '${__SYNC_SOURCE}' via ${__SYNC_MODE}; skipping"
}

function _do_fast_forward() {
    local branch="${1}"
    local path="${2}"

    if git -C "${path}" merge --ff-only "${__SYNC_SOURCE}" > /dev/null 2>&1; then
        ulogger info "synced '${branch}' <- '${__SYNC_SOURCE}' (fast-forward)"
        return 0
    fi

    _fail "failed to fast-forward '${branch}' to '${__SYNC_SOURCE}'"
}

# Stashes the uncommitted changes in a worktree, including untracked files. The
# preceding "git add" ensures untracked files are captured by the stash.
function _stash_push() {
    local branch="${1}"
    local path="${2}"

    local worktree
    local name

    worktree="$(basename "${path}")"
    name="sync-${worktree} @ $(date '+%Y-%m-%dT%H:%M:%S')"

    git -C "${path}" add -A > /dev/null 2>&1 || true

    if git -C "${path}" stash push -m "${name}" > /dev/null 2>&1; then
        ulogger info "stashed changes in '${worktree}' (branch '${branch}') as '${name}'"
        return 0
    fi

    _fail "failed to stash changes in worktree '${worktree}' (branch '${branch}')"
    return 1
}

# Re-applies the most recent stash onto the current worktree/branch and always
# drops it from the stash list, even when it applies with conflicts.
function _stash_pop() {
    local branch="${1}"
    local path="${2}"
    local worktree
    worktree="$(basename "${path}")"

    if git -C "${path}" stash apply > /dev/null 2>&1; then
        git -C "${path}" stash drop > /dev/null 2>&1 || true
        ulogger info "re-applied stashed changes to '${worktree}' (branch '${branch}')"
        return 0
    fi

    # drop regardless: the stash must never linger in the stash list
    git -C "${path}" stash drop > /dev/null 2>&1 || true
    _warn_or_fail "stashed changes could not be re-applied cleanly to '${worktree}' (branch '${branch}')"
}

function _handle_force() {
    local branch="${1}"
    local path="${2}"

    [[ -n "${__SYNC_FORCE}" ]] && return 0

    _fail "worktree '$(basename "${path}")' (branch '${branch}') has uncommitted changes; skipping"
    return 1
}

# Runs an in-place sync (sync_fn) within a checked-out worktree, handling
# uncommitted changes: skip (default) or stash-sync-restore (--force).
function _sync_in_place() {
    local branch="${1}"
    local path="${2}"
    local sync_fn="${3}"
    local stashed=""

    if ! git::is_clean "${path}"; then
        _handle_force "${branch}"  "${path}" || return 0
        _stash_push "${branch}" "${path}" || return 0

        stashed="true"
    fi

    "${sync_fn}" "${branch}" "${path}"
    [[ -n "${stashed}" ]] && _stash_pop "${branch}" "${path}"

    return 0
}

function _sync::checked_out() {
    local branch="${1}"
    local path="${2}"

    _sync_in_place "${branch}" "${path}" _run_sync
}

function _sync::fast_forward() {
    local branch="${1}"
    local path="${2:-}"

    if [[ -n "${path}" ]]; then
        # git refuses to self-fetch into a checked-out branch, so fast-forward in
        # place; --ff-only guarantees no merge commit regardless of mode
        _sync_in_place "${branch}" "${path}" _do_fast_forward
        return 0
    fi

    # a local "self-fetch" moves the ref without a worktree or working tree
    if git fetch --quiet . "${__SYNC_SOURCE}:${branch}" > /dev/null 2>&1; then
        ulogger info "synced '${branch}' <- '${__SYNC_SOURCE}' (fast-forward)"
        return 0
    fi

    _fail "failed to fast-forward '${branch}' to '${__SYNC_SOURCE}'"
}

function _sync::detached() {
    local branch="${1}"
    local tmp="${__SYNC_TMP_ROOT}/${branch//\//_}"

    if ! git worktree add --quiet "${tmp}" "${branch}" > /dev/null 2>&1; then
        _fail "failed to create temporary worktree for branch '${branch}'"
        return 0
    fi

    __SYNC_TEMP_WORKTREES+=("${tmp}")
    _run_sync "${branch}" "${tmp}"

    git worktree remove --force "${tmp}" > /dev/null 2>&1 || true
}

function _init_tmp_root() {
    [[ -n "${__SYNC_TMP_ROOT}" ]] && return 0
    __SYNC_TMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/git-sync.XXXXXX")"
}

function _can_fast_forward() {
    local branch="${1}"

    git::can_fast_forward "${branch}" -s "${__SYNC_SOURCE}"
}

function sync::branch() {
    local branch="${1}" ; shift
    local path

    local OPTIND=1
    while getopts "o:m:f:s:" opt; do
      case $opt in
        o) __SYNC_SOURCE="${OPTARG}" ;;
        m) __SYNC_MODE="${OPTARG}" ;;
        f) __SYNC_FORCE="${OPTARG}" ;;
        s) __SYNC_STRICT="${OPTARG}" ;;
        :) ulogger error "arg required for -ofms" >&2 ; return 1 ;;
        \?) ulogger error "valid flags are -ofms" >&2 ; return 1 ;;
      esac
    done

    _init_tmp_root
    path="$(worktrees::path_for "${branch}")"

    # always prefer a fast-forward, whether or not the branch is checked out
    if _can_fast_forward "${branch}"; then
        _sync::fast_forward "${branch}" "${path}"
    elif [[ -n "${path}" ]]; then
        # diverged checked-out branches must be synced in place; git refuses to
        # fetch into them
        _sync::checked_out "${branch}" "${path}"
    else
        _sync::detached "${branch}"
    fi
}

function _cleanup::tmp_worktrees() {
    [[ ${#__SYNC_TEMP_WORKTREES[@]} -eq 0 ]] && return 0

    for wt in "${__SYNC_TEMP_WORKTREES[@]}"; do
        [[ -d "${wt}" ]] && git worktree remove --force "${wt}" > /dev/null 2>&1 || true
    done
}

function _cleanup::tmp_root() {
    if [[ -n "${__SYNC_TMP_ROOT}" && -d "${__SYNC_TMP_ROOT}" ]]; then 
        rm -rf "${__SYNC_TMP_ROOT}" 2>/dev/null || true
    fi
}

function sync::cleanup() {
    _cleanup::tmp_worktrees
    _cleanup::tmp_root
}

function sync::has_failures() {
    if [[ "${__SYNC_FAILURES}" -eq 0 ]]; then
        return 1
    fi
}
