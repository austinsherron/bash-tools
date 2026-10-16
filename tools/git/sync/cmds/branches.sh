#!/usr/bin/env bash

source "${BASH_LIB}/args/validate.sh"
source "${BASH_LIB}/api/git.sh"

source "${BASH_TOOLS}/tools/git/_helpers/config.sh"
source "${BASH_TOOLS}/tools/git/sync/_helpers/sync.sh"
source "${BASH_TOOLS}/tools/git/_helpers/worktrees.sh"
source "${BASH_TOOLS}/tools/git/sync/cmds/common.sh"


# The "branches" sub-command (the default): syncs the source into each of a set of
# branches, independently of one another.

SYNC_BRANCHES_USAGE="git sync [branches] [-b <branch>]... [--category <category>] [-d] [-s <source>] [-c|-i] [-m ff|merge|rebase] [-f] [--strict]"

function sync_branches::usage() {
    echo "usage: ${SYNC_BRANCHES_USAGE}"
}

function sync_branches::help() {
cat <<help
GIT-SYNC-BRANCHES(1)

NAME

    git sync branches - Merge a source branch into other branches w/out switching
    branches.

SYNOPSIS

    git sync [branches] [-b|--branch <branch>]... [--category <category>]
             [-d|--defaults] [-s|--source <source>] [-c|--check|-i|--interactive]
             [-m|--mode ff|m[erge]|r[ebase]] [-f|--force] [--strict]

DESCRIPTION

    Syncs <source> (default: "master") into one or more branches in the current
    repo. This is the default sub-command, so "branches" may be left out.

    The currently checked out branch is never switched: branches that are
    checked out in a worktree are synced in place w/in that worktree, and
    branches that are not checked out anywhere are synced in a throwaway
    worktree that is removed when the command finishes.

    By default every local branch (except <source>) is synced. Use -b|--branch
    to constrain the set of branches, --category to sync only the branches
    checked out in one category's worktrees, or -d|--defaults to sync only
    configured default branches (see ~/.config/git/config.toml).

    A branch's category is the directory, beneath the worktree root, containing
    the worktree it's checked out in. Branches whose category is listed under
    [<repo>].sync.exclude in ~/.config/git/config.toml are always excluded from
    syncing.

    -m|--mode controls how branches are synced. A branch that can be
    fast-forwarded always is, regardless of mode; the mode only determines what
    happens to branches that have diverged from <source>:

      ff|fast-forward   only fast-forwards are performed; diverged branches are
                        skipped (default)
      m|merge           diverged branches are synced via merge
      r|rebase          diverged branches are synced via rebase

    When a branch cannot be synced cleanly (e.g. a merge conflict) the
    in-progress operation is aborted and a warning is logged; the remaining
    branches are still synced. With --strict, an error is logged instead and the
    command exits immediately with rc=1 on the first such failure.

    Branches whose working tree has uncommitted changes are skipped (an error is
    logged), since they cannot be safely synced in place. With -f|--force those
    changes are instead stashed before the branch is synced and re-applied to
    the same worktree afterward (a "git add" first captures untracked files).
    Each stash is named "sync-<worktree> @ <timestamp>" and is always dropped
    from the stash list once re-applied. If a stash cannot be re-applied cleanly
    a warning is logged (an error, exiting with rc=1, with --strict).

OPTIONS

    -b, --branch <branch>   constrain the branches to sync; may be given
                            multiple times; defaults to all branches
        --category <category>
                            constrain the branches to sync to those checked out
                            in the worktrees of one category
    -s, --source <source>   the branch to sync from; defaults to "master"
    -m, --mode <mode>       how to sync diverged branches: "ff"|"fast-forward"
                            (default), "m"|"merge", or "r"|"rebase"

FLAGS

    -d, --defaults          sync only configured default branches
    -c, --check             do not sync; write to stdout the branches that
                            would be updated by the sync. Exits 0 if none would
                            be updated, 1 otherwise
    -i, --interactive       display a summary of the sync -- each branch, how
                            it'll be synced, and the commits involved -- and
                            prompt for confirmation before syncing
    -f, --force             sync branches with uncommitted changes by stashing
                            them (incl. untracked files) before syncing and
                            re-applying the stash afterward
        --strict            exit with rc=1 on the first failure
    -h, --help              display this message
help
}

## args ########################################################################

BRANCHES=()
CATEGORY=""
DEFAULTS_ONLY=""
SOURCE="master"
CHECK=""
CONFIRM=""
MODE="ff"
FORCE=""
STRICT=""

TARGETS=()

function _sync_branches::parse_args() {
    while [[ $# -gt 0 ]]; do
      case $1 in
        -b|--branch)
          BRANCHES+=("${2}") ; shift 2 ;;
        --category)
          CATEGORY="${2}" ; shift 2 ;;
        -d|--defaults)
          DEFAULTS_ONLY="true" ; shift ;;
        -s|--source)
          SOURCE="${2}" ; shift 2 ;;
        -c|--check)
          CHECK="true" ; shift ;;
        -i|--interactive)
          CONFIRM="true" ; shift ;;
        -m|--mode)
          MODE="${2}" ; shift 2 ;;
        -f|--force)
          FORCE="true" ; shift ;;
        --strict)
          STRICT="true" ; shift ;;
        -h|--help)
          sync_branches::help && exit 0 ;;
        *)
          sync_branches::usage >&2 && exit 1 ;;
      esac
    done
}

function _sync_branches::validate_branch_args() {
    if [[ ${#BRANCHES[@]} -gt 0 && -n "${DEFAULTS_ONLY}" ]]; then
        ulogger error "-b|--branch and -d|--defaults are mutually exclusive"
        exit 1
    fi

    validate_mutually_exclusive \
        "${CATEGORY}" "--category" "${DEFAULTS_ONLY}" "-d|--defaults" || exit 1
}

function _sync_branches::validate_branches_exist() {
    local branch

    for branch in "${BRANCHES[@]:-}"; do
        [[ -z "${branch}" ]] && continue
        sync_cmds::validate_branch_exists "${branch}"
    done
}

function _sync_branches::normalize_mode() {
    case "${MODE}" in
        ff|fast-forward) MODE="fast-forward" ;;
        m|merge)         MODE="merge" ;;
        r|rebase)        MODE="rebase" ;;
        *)
            validate_one_of "-m|--mode" "${MODE}" \
                ff fast-forward m merge r rebase || exit 1
            ;;
    esac
}

function _sync_branches::validate_args() {
    sync_cmds::validate_in_repo
    _sync_branches::normalize_mode
    _sync_branches::validate_branch_args
    sync_cmds::validate_interactive "${CONFIRM}" "${CHECK}"
    sync_cmds::validate_branch_exists "${SOURCE}" "source"
    _sync_branches::validate_branches_exist
}

## targets #####################################################################

function _sync_branches::is_skipped_default() {
    local branch="${1}"
    [[ -n "${DEFAULTS_ONLY}" ]] && ! config::is_default_branch "${branch}"
}

function _sync_branches::get_candidates() {
    local -n _out="${1}"
    _out=("${BRANCHES[@]}")

    [[ ${#_out[@]} -gt 0 ]] && return 0

    while IFS= read -r branch; do
        _sync_branches::is_skipped_default "${branch}" && continue
        _out+=("${branch}")
    done < <(git for-each-ref --format='%(refname:short)' refs/heads/)
}

function _sync_branches::is_excluded() {
    local branch="${1}"
    local category

    worktrees::category_for "${branch}" category
    [[ -z "${category}" ]] && return 1

    config::is_sync_excluded_category "${category}" || return 1
    ulogger info "excluding '${branch}': category '${category}' is in sync.exclude"
}

function _sync_branches::is_other_category() {
    local branch="${1}"
    local category

    [[ -n "${CATEGORY}" ]] || return 1

    worktrees::category_for "${branch}" category
    [[ "${category}" != "${CATEGORY}" ]]
}

function _sync_branches::should_update() {
    local branch="${1}"

    git::is_ancestor "${SOURCE}" "${branch}" || return 0
    ulogger info "excluding '${branch}': branch already contains '${SOURCE}'"
    return 1
}

function _sync_branches::is_target() {
    local branch="${1}"

    if _sync_branches::is_excluded "${branch}" ||
        _sync_branches::is_other_category "${branch}"; then
        return 1
    fi

    if ! _sync_branches::should_update "${branch}"; then
        return 1
    fi

    if [[ "${MODE}" != "fast-forward" ]] ||
        git::can_fast_forward "${branch}" -s "${SOURCE}"; then
        return 0
    fi

    ulogger info "excluding '${branch}': cannot be fast-forward merged w/ '${SOURCE}'"
    return 1
}

function _sync_branches::select_targets() {
    local candidates=()
    local branch

    _sync_branches::get_candidates candidates

    for branch in "${candidates[@]}"; do
        [[ "${branch}" = "${SOURCE}" ]] && continue
        _sync_branches::is_target "${branch}" || continue

        TARGETS+=("${branch}")
    done
}

## summary #####################################################################

#######################################
# Describes how a branch will be synced: its sync method, the commits involved,
# and the worktree it's synced in.
# Arguments:
#   branch: the branch to describe
#   width: the width to pad the branch to
#######################################
function _sync_branches::summarize_branch() {
    local branch="${1}"
    local width="${2}"

    local method="${MODE}"
    local behind ahead commits worktree path

    git::can_fast_forward "${branch}" -s "${SOURCE}" && method="fast-forward"

    behind="$(git rev-list --count "${branch}..${SOURCE}")"
    ahead="$(git rev-list --count "${SOURCE}..${branch}")"

    commits="${behind} new"
    [[ "${ahead}" -gt 0 ]] && commits+=", ${ahead} local"

    sync_cmds::worktree_of "${branch}" worktree path

    if [[ -n "${path}" ]] && ! git::is_clean "${path}"; then
        if [[ -n "${FORCE}" ]]; then
            worktree+="; uncommitted changes will be stashed"
        else
            worktree+="; uncommitted changes, so it'll be skipped"
        fi
    fi

    printf '    %s  %-14s%-20s%s\n' \
        "$(sync_cmds::style_branch "${branch}" "${width}")" \
        "${method}" "${commits}" "${worktree}"
}

function _sync_branches::summarize() {
    local width branch

    width="$(sync_cmds::max_width "${TARGETS[@]}")"

    echo "syncing ${#TARGETS[@]} branch(es) w/ '${SOURCE}':"
    echo

    for branch in "${TARGETS[@]}"; do
        _sync_branches::summarize_branch "${branch}" "${width}"
    done
}

## main ########################################################################

function _sync_branches::sync() {
    local branch

    for branch in "${TARGETS[@]}"; do
        sync::branch "${branch}" -o "${SOURCE}" -m "${MODE}" -f "${FORCE}" -s "${STRICT}"
    done

    if sync::has_failures; then
        return 1
    fi
}

#######################################
# Runs the "branches" sub-command.
# Arguments:
#   args: the sub-command's args (see: sync_branches::help)
#######################################
function sync_branches::main() {
    _sync_branches::parse_args "$@"
    _sync_branches::validate_args
    _sync_branches::select_targets

    if [[ ${#TARGETS[@]} -eq 0 ]]; then
        ulogger info "no branches to sync"
        return 0
    fi

    if [[ -n "${CHECK}" ]]; then
        sync_cmds::check "${TARGETS[@]}" || return 1
        return 0
    fi

    if [[ -n "${CONFIRM}" ]]; then
        _sync_branches::summarize

        if ! sync_cmds::confirm; then
            ulogger info "nothing synced"
            return 0
        fi
    fi

    _sync_branches::sync
}
