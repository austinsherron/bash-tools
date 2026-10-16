#!/usr/bin/env bash

source "${BASH_LIB}/args/validate.sh"
source "${BASH_LIB}/api/git.sh"

source "${BASH_TOOLS}/tools/git/_helpers/stack.sh"
source "${BASH_TOOLS}/tools/git/sync/_helpers/sync.sh"
source "${BASH_TOOLS}/tools/git/sync/cmds/common.sh"


# The "stack" sub-command: rebases a stack of branches (see: git/_helpers/stack.sh)
# onto the source, or w/ -p|--propagate, propagates new commits in one branch of a
# stack up to the branches built on it.

SYNC_STACK_USAGE="git sync stack [-b <branch>] [-s <source>] [-p] [-c|-i] [-f] [--strict]"

function sync_stack::usage() {
    echo "usage: ${SYNC_STACK_USAGE}"
}

function sync_stack::help() {
cat <<help
GIT-SYNC-STACK(1)

NAME

    git sync stack - Rebase a stack of branches in one go.

SYNOPSIS

    git sync stack [-b|--branch <branch>] [-s|--source <source>] [-p|--propagate]
                   [-c|--check|-i|--interactive] [-f|--force] [--strict]

DESCRIPTION

    A stack is a line of branches, each built on the one before it, on top of
    <source> (default: "master"). The stack is found from the current branch
    (or the one given by -b|--branch).

    By default, the whole stack is rebased onto <source> w/ "git rebase
    --update-refs". The stack is walked up to the branch it all leads to: its
    tip. The tip is rebased, even if it isn't the current branch, and every
    branch below it in the stack moves along w/ it.

PROPAGATE MODE

    W/ -p|--propagate, new commits in the branch (e.g. ones added to, or
    amended in, a branch in the middle of the stack) are instead carried up to
    the branches built on it. Those branches are rebased onto the branch, and
    nothing below it moves. Nothing is rebased onto <source>; it's only used to
    find the bottom of the stack.

    A branch is built on the given one if it was built on any of the commits
    the given branch has pointed at, now or in the past (per its reflog). This
    is how the branches above are still found after the given branch's commits
    were amended or rebased.

    If some branches above already have the new commits and others don't, run
    the command again from the topmost branch that has them.

WORKTREES

    git won't move a branch that's checked out in another worktree, so each
    such branch's worktree is first switched to a throwaway branch named
    "__tmp-<worktree>-<id>". Once the rebase is done (or has failed) each
    worktree is switched back and its throwaway branch is deleted. If any
    branch can't be switched out, nothing is rebased.

    Switching a worktree out doesn't touch its files, so its uncommitted
    changes stay put and are carried back onto the rebased branch. If the
    rebase changed the same files, git refuses to switch back rather than
    overwrite them: w/ -f|--force the changes are stashed around the switch;
    otherwise the worktree is left on its throwaway branch and the commands to
    finish by hand are logged. The tip is rebased in place: w/out -f|--force,
    it's skipped if it has uncommitted changes; w/ it, they're stashed around
    the rebase.

    A stack that forks into several tips is refused. Branches that fork off
    the stack below its tip are left behind by the rebase; a warning names
    them. A rebase that can't complete cleanly is aborted and a warning is
    logged; w/ --strict, an error is logged and the command exits w/ rc=1.

OPTIONS

    -b, --branch <branch>   the branch whose stack to rebase, or w/
                            -p|--propagate, the branch whose commits to
                            propagate; defaults to the current branch
    -s, --source <source>   the branch the stack is built on; defaults to
                            "master"

FLAGS

    -p, --propagate         propagate the branch's commits up the stack,
                            rather than rebase the stack onto <source>
    -c, --check             do not rebase; write to stdout the branches that
                            would be rebased. Exits 0 if none would be, 1
                            otherwise
    -i, --interactive       display a summary of the rebase -- each branch,
                            the commits it'll replay, and what becomes of its
                            worktree -- and prompt for confirmation before
                            rebasing
    -f, --force             stash uncommitted changes that would block the
                            rebase, and re-apply them afterward
        --strict            exit with rc=1 on the first failure
    -h, --help              display this message
help
}

## args ########################################################################

BRANCH=""
SOURCE="master"
PROPAGATE=""
CHECK=""
CONFIRM=""
FORCE=""
STRICT=""

TIP=""
UPSTREAM=""
TARGETS=()

function _sync_stack::parse_args() {
    while [[ $# -gt 0 ]]; do
      case $1 in
        -b|--branch)
          if [[ -n "${BRANCH}" ]]; then
              ulogger error "-b|--branch may only be given once"
              exit 1
          fi
          BRANCH="${2}" ; shift 2 ;;
        -s|--source)
          SOURCE="${2}" ; shift 2 ;;
        -p|--propagate)
          PROPAGATE="true" ; shift ;;
        -c|--check)
          CHECK="true" ; shift ;;
        -i|--interactive)
          CONFIRM="true" ; shift ;;
        -f|--force)
          FORCE="true" ; shift ;;
        --strict)
          STRICT="true" ; shift ;;
        -h|--help)
          sync_stack::help && exit 0 ;;
        *)
          sync_stack::usage >&2 && exit 1 ;;
      esac
    done
}

function _sync_stack::validate_args() {
    sync_cmds::validate_in_repo
    sync_cmds::validate_interactive "${CONFIRM}" "${CHECK}"
    sync_cmds::validate_branch_exists "${SOURCE}" "source"
    [[ -n "${BRANCH}" ]] && sync_cmds::validate_branch_exists "${BRANCH}"

    return 0
}

#######################################
# Resolves the branch the stack is found from, and exits w/ rc=1 if it can't be
# in a stack on the source.
# Arguments:
#   out: the name of the variable to assign the branch to
#######################################
function _sync_stack::start() {
    local -n __sync_stack_start_out="${1}"

    sync_cmds::start_branch "${BRANCH}" "${1}"

    if [[ "${__sync_stack_start_out}" = "${SOURCE}" ]]; then
        ulogger error "'${SOURCE}' is the source branch; it has no stack"
        exit 1
    fi

    if git::is_ancestor "${__sync_stack_start_out}" "${SOURCE}"; then
        ulogger error "'${__sync_stack_start_out}' is already contained in '${SOURCE}'; it has no stack"
        exit 1
    fi
}

## rebase ######################################################################

function _sync_stack::warn_forks() {
    local forks=()
    local branch

    stack::forks "${TIP}" "${SOURCE}" forks

    for branch in "${forks[@]}"; do
        ulogger warn "'${branch}' forks off the stack below '${TIP}' and won't be rebased"
    done
}

function _sync_stack::select_rebase() {
    local start

    _sync_stack::start start
    stack::tip "${start}" "${SOURCE}" TIP || exit 1

    if git::is_ancestor "${SOURCE}" "${TIP}"; then
        ulogger info "the stack tipped by '${TIP}' already contains '${SOURCE}'"
        return 0
    fi

    stack::branches "${TIP}" "${SOURCE}" TARGETS
    _sync_stack::warn_forks
}

## propagate ###################################################################

#######################################
# Splits the branches built on a branch into those that already contain it, and
# those that don't (i.e.: those to propagate its commits to).
# Arguments:
#   branch: the branch whose commits to propagate
#   stale: the name of the array to copy the branches that don't contain it into
#   current: the name of the array to copy the branches that do contain it into
#######################################
function _sync_stack::split_built_on() {
    local branch="${1}"
    local -n __sync_stack_stale_out="${2}"
    local -n __sync_stack_current_out="${3}"

    local parent b
    local built_on=()

    stack::parent "${branch}" "${SOURCE}" parent
    stack::built_on "${branch}" "${parent}" built_on

    for b in "${built_on[@]}"; do
        if git::is_ancestor "${branch}" "${b}"; then
            __sync_stack_current_out+=("${b}")
        else
            __sync_stack_stale_out+=("${b}")
        fi
    done
}

#######################################
# Finds the tip of the branches to propagate to: the one every other one leads up
# to. When several branches point at the tip commit, the first by name is used.
# Exits w/ rc=1 if they fork into several tips.
# Arguments:
#   start: the branch whose commits are propagated
#   branches: the branches to propagate to
#######################################
function _sync_stack::propagation_tip() {
    local start="${1}" ; shift

    local -A tips=()
    local tip_branches=()
    local sha b

    while IFS= read -r sha; do
        tips["${sha}"]="true"
    done < <(git merge-base --independent "$@")

    for b in "$@"; do
        [[ -n "${tips[$(git rev-parse "${b}")]+x}" ]] && tip_branches+=("${b}")
    done

    if [[ ${#tips[@]} -gt 1 ]]; then
        ulogger error "the stack above '${start}' forks into several tips:"
        for b in "${tip_branches[@]}"; do
            ulogger error "    ${b}"
        done
        exit 1
    fi

    TIP="$(printf '%s\n' "${tip_branches[@]}" | sort | head -n 1)"
}

function _sync_stack::select_propagation() {
    local start b
    local stale=()
    local current=()

    _sync_stack::start start
    _sync_stack::split_built_on "${start}" stale current

    if [[ ${#stale[@]} -eq 0 ]]; then
        if [[ ${#current[@]} -eq 0 ]]; then
            ulogger info "no branches are built on '${start}'"
        else
            ulogger info "every branch built on '${start}' already contains it"
        fi
        return 0
    fi

    # the stale branches were built on the current ones' old commits, so they'd be
    # rebased onto the start branch w/ duplicates of those commits
    if [[ ${#current[@]} -gt 0 ]]; then
        ulogger error "some branches built on '${start}' already contain it:"
        for b in "${current[@]}"; do
            ulogger error "    ${b}"
        done
        ulogger error "re-run from the topmost of them, i.e.: git sync stack -p -b <branch>"
        exit 1
    fi

    _sync_stack::propagation_tip "${start}" "${stale[@]}"
    stack::fork_point "${TIP}" "${start}" UPSTREAM

    # the start branch is the source of the propagation
    SOURCE="${start}"
    stack::branches "${TIP}" "${UPSTREAM}" TARGETS
}

## summary #####################################################################

#######################################
# Describes what the rebase does to a branch's worktree, if it's checked out.
# Arguments:
#   branch: the branch to describe
#   out: the name of the variable to assign the description to
#######################################
function _sync_stack::worktree_note() {
    local branch="${1}"
    local -n __sync_stack_note_out="${2}"
    local path

    sync_cmds::worktree_of "${branch}" __sync_stack_note_out path
    [[ -n "${path}" ]] || return 0

    if [[ "${branch}" = "${TIP}" ]]; then
        __sync_stack_note_out+=", rebased in place"
    else
        __sync_stack_note_out+=", switched out during the rebase"
    fi

    git::is_clean "${path}" && return 0

    if [[ "${branch}" != "${TIP}" ]]; then
        __sync_stack_note_out+="; uncommitted changes carried along"
    elif [[ -n "${FORCE}" ]]; then
        __sync_stack_note_out+="; uncommitted changes will be stashed"
    else
        __sync_stack_note_out+="; uncommitted changes, so nothing will be rebased"
    fi
}

#######################################
# Displays each branch to rebase, bottom to tip, w/ the commits it'll replay and
# what becomes of its worktree.
#######################################
function _sync_stack::summarize() {
    local base new width branch commits note

    if [[ -n "${UPSTREAM}" ]]; then
        base="${UPSTREAM}"
        echo "propagating '${SOURCE}' up the stack, onto its new commits:"
    else
        base="$(git merge-base "${SOURCE}" "${TIP}")"
        new="$(git rev-list --count "${base}..${SOURCE}")"
        echo "rebasing the stack onto '${SOURCE}' (${new} new commit(s)):"
    fi

    echo
    width="$(sync_cmds::max_width "${TARGETS[@]}")"

    for branch in "${TARGETS[@]}"; do
        commits="$(git rev-list --count "${base}..${branch}") commit(s)"
        base="${branch}"

        _sync_stack::worktree_note "${branch}" note

        printf '    %s  %-14s%s\n' \
            "$(sync_cmds::style_branch "${branch}" "${width}")" "${commits}" "${note}"
    done
}

## main ########################################################################

function _sync_stack::sync() {
    local upstream=()
    [[ -n "${UPSTREAM}" ]] && upstream=(-u "${UPSTREAM}")

    sync::stack "${TIP}" -o "${SOURCE}" ${upstream[@]+"${upstream[@]}"} \
        -f "${FORCE}" -s "${STRICT}"

    if sync::has_failures; then
        return 1
    fi
}

#######################################
# Runs the "stack" sub-command.
# Arguments:
#   args: the sub-command's args (see: sync_stack::help)
#######################################
function sync_stack::main() {
    _sync_stack::parse_args "$@"
    _sync_stack::validate_args

    if [[ -n "${PROPAGATE}" ]]; then
        _sync_stack::select_propagation
    else
        _sync_stack::select_rebase
    fi

    if [[ ${#TARGETS[@]} -eq 0 ]]; then
        ulogger info "no branches to sync"
        return 0
    fi

    if [[ -n "${CHECK}" ]]; then
        sync_cmds::check "${TARGETS[@]}" || return 1
        return 0
    fi

    if [[ -n "${CONFIRM}" ]]; then
        _sync_stack::summarize

        if ! sync_cmds::confirm; then
            ulogger info "nothing rebased"
            return 0
        fi
    fi

    _sync_stack::sync
}
