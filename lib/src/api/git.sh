#!/usr/bin/env bash

source "${BASH_LIB}/args/validate.sh"
source "${BASH_LIB}/core/_shared.sh"


validate_installed git.sh git


## state #######################################################################

# A command's repo layout doesn't change while it runs, so the paths derived from
# it are resolved once and memoized. Lookups used to recompute them per call,
# which cost a fork ("git", "realpath", "dirname") per lookup and made
# per-branch loops quadratic in worktree count.

__GIT_ROOT=""                           # the repo/primary worktree path
__GIT_WORKTREE=""                       # the active worktree path

# The worktree listing, loaded once by __git::load_worktrees and keyed by
# worktree path. Every worktree lookup in this module reads from it.

__GIT_WORKTREE_ROOT=""                  # the dir holding the category dirs
__GIT_MAIN_WORKTREE=""                  # main worktree path, per the listing
__GIT_WORKTREE_PATHS=()                 # worktree paths, main worktree first
declare -A __GIT_WORKTREE_BRANCH        # worktree path -> branch (short)
declare -A __GIT_WORKTREE_REL           # worktree path -> "<category>/<item>"
declare -A __GIT_WORKTREE_LOCKED        # worktree path -> lock reason, if locked

__GIT_WORKTREES_LOADED=""


## repo ########################################################################

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
#
# NOTE: Memoized: the value is fixed for the life of the process.
#
# Outputs:
#   Writes to stdout the root path of the main repository
#######################################
function git::root() {
    if [[ -z "${__GIT_ROOT}" ]]; then
        local common
        common="$(git rev-parse --path-format=absolute --git-common-dir)" || return 1
        __GIT_ROOT="${common%/*}"
    fi

    echo "${__GIT_ROOT}"
}

#######################################
# Displays the name of the current repo.
# Outputs:
#   Writes to stdout the basename of the current repo.
#######################################
function git::repo_name() {
    local root ; root="$(git::root)" || return 1
    echo "${root##*/}"
}

#######################################
# Displays the path of the active worktree. Memoized.
# Outputs:
#   Writes to stdout the path of the active worktree
#######################################
function git::worktree() {
    if [[ -z "${__GIT_WORKTREE}" ]]; then
        __GIT_WORKTREE="$(git rev-parse --show-toplevel)" || return 1
    fi

    echo "${__GIT_WORKTREE}"
}

#######################################
# Checks if the current directory is in a worktree associated w/ the provided repo.
# Arguments:
#   repo: the name of the repo to check.
# Returns:
#   0 if the current directory is in a worktree repo, 1 otherwise
#######################################
function git::in_repo_worktree() {
    local repo="${1}"

    git::in_repo || return 1
    [[ "${repo}" = "$(git::repo_name)" ]]
}

## refs ########################################################################

#######################################
# Checks if a branch w/ the provided name exists in the current repo.
# Arguments:
#   branch: the name of the branch to check
# Returns:
#   0 if a branch w/ the provided name exists in the current repo, 1 otherwise
#######################################
function git::branch_exists() {
    local branch="${1}"
    git show-ref --verify --quiet "refs/heads/${branch}"
}

#######################################
# Checks whether one ref is an ancestor of another, i.e.: whether the descendant
# already contains every commit reachable from the ancestor.
# Arguments:
#   ancestor:   the ref that may be contained (e.g. "master")
#   descendant: the ref that may contain the ancestor
# Returns:
#   0 if ancestor is an ancestor of descendant, 1 otherwise
#######################################
function git::is_ancestor() {
    git merge-base --is-ancestor "${1}" "${2}"
}

#######################################
# Checks if a branch can be fast-forwarded (based on a source branch).
# Arguments:
#   branch: the branch to check
#   -s: optional, defaults to master; the source branch
# Returns:
#   0 if branch can be fast-forwarded, 1 otherwise
#######################################
function git::can_fast_forward() {
    local branch="${1}" ; shift
    local source="master"

    local OPTIND=1
    while getopts "s:" opt; do
      case $opt in
        s) source="${OPTARG}" ;;
        \?) ulogger error "valid flags are -s" >&2 ; return 1 ;;
      esac
    done
    shift $((OPTIND - 1))

    git::is_ancestor "${branch}" "${source}"
}

#######################################
# Displays the branch checked out in the current (or provided) worktree. A
# detached worktree resolves to the empty string.
#
# Unlike git::worktree_branch this asks git directly rather than reading the
# memoized listing, so it reflects a checkout made since the listing was loaded.
# Arguments:
#   dir: optional, defaults to the current worktree; the worktree to inspect
# Outputs:
#   Writes the checked-out branch to stdout
#######################################
function git::current_branch() {
    local dir="${1:-}"
    local args=(branch --show-current)

    [[ -n "${dir}" ]] && args=(-C "${dir}" "${args[@]}")
    git "${args[@]}"
}

#######################################
# Copies the local branches that contain a ref (i.e.: that the ref is an ancestor
# of, the ref's own branch included) into the caller's array.
# Arguments:
#   ref: the ref the branches must contain
#   out: the name of the array to populate
#######################################
function git::branches_containing() {
    local ref="${1}"
    local -n __git_containing_out="${2}"

    __git_containing_out=()

    local branch
    while IFS= read -r branch; do
        __git_containing_out+=("${branch}")
    done < <(git for-each-ref --contains "${ref}" --format='%(refname:short)' refs/heads/)
}

#######################################
# Copies the local branches that point at a commit in the range "<base>..<tip>"
# into the caller's array, ordered from nearest <base> to nearest <tip>. These
# are the branches that "git rebase --update-refs" moves when <tip> is rebased
# onto <base>. Branches that point at the same commit are ordered by name.
# Arguments:
#   base: the exclusive start of the range (e.g. "master")
#   tip: the inclusive end of the range
#   out: the name of the array to populate
#######################################
function git::branches_in_range() {
    local base="${1}"
    local tip="${2}"
    local -n __git_range_out="${3}"

    __git_range_out=()

    local -A position=()
    local sha branch
    local i=0

    while IFS= read -r sha; do
        position["${sha}"]="${i}"
        i=$((i + 1))
    done < <(git rev-list --reverse "${base}..${tip}")

    [[ ${#position[@]} -eq 0 ]] && return 0

    while IFS= read -r branch; do
        __git_range_out+=("${branch}")
    done < <(
        git for-each-ref --format='%(objectname) %(refname:short)' refs/heads/ |
            while read -r sha branch; do
                [[ -n "${position[${sha}]+x}" ]] && echo "${position[${sha}]} ${branch}"
            done |
            sort -k1,1n -k2,2 |
            cut -d' ' -f2-
    )
}

#######################################
# Creates a branch, w/out checking it out anywhere.
# Arguments:
#   branch: the branch to create
#   start: optional, defaults to HEAD; the start point to create it from
# Returns:
#   0 if the branch was created, 1 otherwise
#######################################
function git::create_branch() {
    local branch="${1}"
    local start="${2:-HEAD}"

    git branch "${branch}" "${start}"
}

#######################################
# Deletes a branch.
#
# A branch that isn't fully merged is kept, and reported by git, unless -f is
# given: the default can't drop commits that live nowhere else.
#
# The branch can't be checked out anywhere -- git refuses to delete one a
# worktree is holding -- so a branch deleted alongside its worktree goes after
# it (see: git::remove_worktree).
# Arguments:
#   branch: the branch to delete
#   -f: delete the branch even if it isn't fully merged
# Returns:
#   0 if the branch was deleted, 1 otherwise
#######################################
function git::delete_branch() {
    local branch="${1}" ; shift

    # -d refuses an unmerged branch; -D deletes it regardless
    local flag="-d"

    local OPTIND=1
    while getopts "f" opt; do
      case $opt in
        f) flag="-D" ;;
        \?) ulogger error "valid flags are -f" >&2 ; return 1 ;;
      esac
    done
    shift $((OPTIND - 1))

    git branch "${flag}" "${branch}"
}

## status ######################################################################

#######################################
# Checks if the current (or provided) git repo has uncommitted changes.
# Arguments:
#   -u: ignore untracked files; only consider changes to tracked files
#   dir: optional, defaults to current repo; the repo to check
# Returns:
#   0 if the repo has no uncommitted changes, 1 otherwise
#######################################
function git::is_clean() {
    local untracked="normal"

    local OPTIND=1
    while getopts "u" opt; do
      case $opt in
        u) untracked="no" ;;
        \?) ulogger error "valid flags are -u" >&2 ; return 1 ;;
      esac
    done
    shift $((OPTIND - 1))

    local dir="${1:-}"
    local args=(status --porcelain "--untracked-files=${untracked}")

    # "git -C" chdirs before running, so it resolves relative and symlinked
    # paths itself; canonicalizing first would just cost a fork
    [[ -n "${dir}" ]] && args=(-C "${dir}" "${args[@]}")
    [[ -z "$(git "${args[@]}")" ]]
}

## worktrees: internal #########################################################

__GIT_REL=""                            # scratch output for __git::rel_for


#######################################
# Computes a worktree's identifier relative to the worktree root, writing it to
# the __GIT_REL scratch global. Pure string manipulation: this runs once per
# worktree per process, so it must not fork.
# Arguments:
#   path: the worktree path to identify
#   main: the main worktree's path
#   root: the worktree root
#######################################
function __git::rel_for() {
    local path="${1%/}"
    local main="${2}"
    local root="${3}"

    if [[ "${path}" = "${main}" ]]; then
        # the main worktree sits alongside the worktrees dir rather than inside
        # it, so it's its own category
        __GIT_REL="${path##*/}"
    elif [[ "${path}" = "${root}/"* ]]; then
        __GIT_REL="${path#"${root}"/}"
    elif [[ "${path}" = "${root%/*}/"* ]]; then
        # a worktree predating the worktrees dir: still a direct child of the
        # repo's parent, and still its own category
        __GIT_REL="${path#"${root%/*}"/}"
    else
        # a worktree outside the repo's tree entirely (e.g.: a throwaway one
        # under /tmp). Stripping a prefix it doesn't have would leave the rel
        # absolute, whose leading "/" makes "${rel%%/*}" -- the category -- empty,
        # so it's named by its basename and, like the main worktree, is its own
        # category
        __GIT_REL="${path##*/}"
    fi
}

#######################################
# Loads the repo's worktree listing: paths, branches, and relative identifiers.
# Every worktree lookup below reads from this map, so a command runs
# "git worktree list" once rather than once per lookup.
#######################################
function __git::load_worktrees() {
    [[ -n "${__GIT_WORKTREES_LOADED}" ]] && return 0
    __GIT_WORKTREES_LOADED="true"

    local path=""
    local line

    while IFS= read -r line; do
        case "${line}" in
            worktree\ *)
                path="${line#worktree }"
                path="${path%/}"
                __GIT_WORKTREE_PATHS+=("${path}")
                ;;
            branch\ *)
                [[ -n "${path}" ]] && __GIT_WORKTREE_BRANCH["${path}"]="${line#branch refs/heads/}"
                ;;
            locked|locked\ *)
                # a bare "locked" is a lock w/out a reason, so the key's presence
                # is the lock -- not the value, which is then empty
                [[ -n "${path}" ]] && __GIT_WORKTREE_LOCKED["${path}"]="${line#locked }"
                ;;
        esac
    done < <(git worktree list --porcelain)

    [[ ${#__GIT_WORKTREE_PATHS[@]} -eq 0 ]] && return 0

    # git lists the main worktree first. Taking it from the listing, rather than
    # from git::root, keeps the comparison exact: both sides of it then come from
    # the same git output, so a repo reached through a symlink still matches
    # without a "realpath" per worktree.
    __GIT_MAIN_WORKTREE="${__GIT_WORKTREE_PATHS[0]}"

    local root="${__GIT_MAIN_WORKTREE%/*}/worktrees"

    for path in "${__GIT_WORKTREE_PATHS[@]}"; do
        __git::rel_for "${path}" "${__GIT_MAIN_WORKTREE}" "${root}"
        __GIT_WORKTREE_REL["${path}"]="${__GIT_REL}"
    done

    return 0
}

#######################################
# Discards the memoized worktree listing, so the next lookup reloads it. Called
# after this module adds or removes a worktree.
#######################################
function __git::invalidate_worktrees() {
    __GIT_WORKTREES_LOADED=""
    __GIT_MAIN_WORKTREE=""
    __GIT_WORKTREE_PATHS=()

    unset __GIT_WORKTREE_BRANCH __GIT_WORKTREE_REL __GIT_WORKTREE_LOCKED
    declare -gA __GIT_WORKTREE_BRANCH
    declare -gA __GIT_WORKTREE_REL
    declare -gA __GIT_WORKTREE_LOCKED
}

## worktrees: layout ###########################################################

#######################################
# Displays the directory that contains the repo's worktree category directories:
# a "worktrees" dir alongside the repo itself. Memoized.
# Outputs:
#   Writes the worktree root to stdout.
#######################################
function git::worktree_root() {
    if [[ -z "${__GIT_WORKTREE_ROOT}" ]]; then
        local root ; root="$(git::root)" || return 1
        __GIT_WORKTREE_ROOT="${root%/*}/worktrees"
    fi

    echo "${__GIT_WORKTREE_ROOT}"
}

#######################################
# Displays a worktree's path relative to the worktree root, i.e.: its stable
# "<category>/<item>" identifier. The main worktree, which sits alongside the
# category directories rather than inside one, resolves to a single component.
# Arguments:
#   path: optional, defaults to the active worktree; the worktree to identify
# Outputs:
#   Writes the relative worktree identifier to stdout
#######################################
function git::worktree_rel() {
    local path="${1:-}"
    [[ -n "${path}" ]] || path="$(git::worktree)"
    path="${path%/}"

    __git::load_worktrees

    if [[ -n "${__GIT_WORKTREE_REL[${path}]+x}" ]]; then
        echo "${__GIT_WORKTREE_REL[${path}]}"
        return 0
    fi

    # The path isn't one git listed, so it's either a non-canonical spelling of a
    # worktree (relative, or through a symlink) or a path outside the listing
    # (e.g.: a throwaway worktree added since it was loaded). Canonicalizing
    # costs a fork, so it's deferred to this miss.
    path="$(realpath "${path}" 2>/dev/null || echo "${path}")"
    path="${path%/}"

    if [[ -n "${__GIT_WORKTREE_REL[${path}]+x}" ]]; then
        echo "${__GIT_WORKTREE_REL[${path}]}"
        return 0
    fi

    __git::rel_for \
        "${path}" "${__GIT_MAIN_WORKTREE:-$(git::root)}" "$(git::worktree_root)"
    echo "${__GIT_REL}"
}

#######################################
# Displays the category of the active/provided worktree: the first path component
# beneath the worktree root. Branches are classified by the directory their
# worktree lives in, not by the worktree itself.
#
# The main worktree has no category directory of its own, so it's treated as its
# own category (i.e.: the repo name).
# Arguments:
#   path: optional, defaults to the active worktree; the worktree to classify
# Outputs:
#   Writes the worktree's category to stdout
#######################################
function git::worktree_category() {
    local rel ; rel="$(git::worktree_rel "${1:-}")"
    echo "${rel%%/*}"
}

#######################################
# Displays the name of the active/provided worktree, i.e.: the "work item" name.
# Arguments:
#   path: optional, defaults to the active worktree; the worktree to name
# Outputs:
#   Writes to stdout the name of the worktree
#######################################
function git::worktree_name() {
    local path="${1:-}"
    [[ -n "${path}" ]] || path="$(git::worktree)"

    path="${path%/}"
    echo "${path##*/}"
}

#######################################
# Checks if the active/provided worktree is the repo's main worktree.
# Arguments:
#   path: optional, defaults to the active worktree; the worktree to check
# Returns:
#   0 if the worktree is the main worktree, 1 otherwise
#######################################
function git::is_main_worktree() {
    local path="${1:-}"
    [[ -n "${path}" ]] || path="$(git::worktree)"
    path="${path%/}"

    __git::load_worktrees

    [[ "${path}" = "${__GIT_MAIN_WORKTREE}" ]] && return 0

    # a path git itself listed needs no canonicalizing: it either matched the
    # main worktree above or isn't it
    [[ -n "${__GIT_WORKTREE_REL[${path}]+x}" ]] && return 1

    [[ "$(realpath "${path}" 2>/dev/null)" = "${__GIT_MAIN_WORKTREE}" ]]
}

## worktrees: queries ##########################################################

#######################################
# Displays the branch checked out in the active/provided worktree. A detached
# worktree has no branch and resolves to the empty string.
# Arguments:
#   path: optional, defaults to the active worktree; the worktree to inspect
# Outputs:
#   Writes the worktree's branch to stdout
#######################################
function git::worktree_branch() {
    local path="${1:-}"
    [[ -n "${path}" ]] || path="$(git::worktree)"

    __git::load_worktrees
    echo "${__GIT_WORKTREE_BRANCH[${path%/}]:-}"
}

#######################################
# Copies the current repo's worktree paths, main worktree first, into the
# caller's array. Unlike git::list_worktrees this needs no subshell, so callers
# that then look each path up pay nothing per worktree.
# Arguments:
#   out: the name of the array to populate
#######################################
function git::worktree_paths() {
    __git::load_worktrees

    local -n __git_paths_out="${1}"
    __git_paths_out=(${__GIT_WORKTREE_PATHS[@]+"${__GIT_WORKTREE_PATHS[@]}"})
}

#######################################
# Displays the current repo's worktrees.
# Arguments:
#   -n: if provided, display worktree names (i.e.: basenames), instead of paths
#   -r: if provided, display worktree identifiers relative to the worktree root
#       (i.e.: "<category>/<item>"), instead of paths
# Outputs:
#   Writes to stdout the current repo's worktrees
#######################################
function git::list_worktrees() {
    local mode="path"

    local OPTIND=1
    while getopts "nr" opt; do
      case $opt in
        n) mode="name" ;;
        r) mode="rel" ;;
        \?) ulogger error "valid flags are -nr" >&2 ; return 1 ;;
      esac
    done
    shift $((OPTIND - 1))

    __git::load_worktrees
    [[ ${#__GIT_WORKTREE_PATHS[@]} -eq 0 ]] && return 0

    local path
    for path in "${__GIT_WORKTREE_PATHS[@]}"; do
        case "${mode}" in
            name) echo "${path##*/}" ;;
            rel)  echo "${__GIT_WORKTREE_REL[${path}]}" ;;
            *)    echo "${path}" ;;
        esac
    done

    return 0
}

#######################################
# Displays the categories in use by the current repo's worktrees, deduplicated
# and sorted.
# Outputs:
#   Writes to stdout the current repo's worktree categories
#######################################
function git::list_categories() {
    __git::load_worktrees
    [[ ${#__GIT_WORKTREE_PATHS[@]} -eq 0 ]] && return 0

    local -A categories=()
    local path

    for path in "${__GIT_WORKTREE_PATHS[@]}"; do
        categories["${__GIT_WORKTREE_REL[${path}]%%/*}"]="true"
    done

    printf '%s\n' "${!categories[@]}" | sort
}

#######################################
# Displays the paths of the worktrees belonging to a category.
# Arguments:
#   category: the category whose worktrees to list
# Outputs:
#   Writes to stdout the paths of the category's worktrees
#######################################
function git::worktrees_in() {
    local category="${1}"

    __git::load_worktrees
    [[ ${#__GIT_WORKTREE_PATHS[@]} -eq 0 ]] && return 0

    local path
    for path in "${__GIT_WORKTREE_PATHS[@]}"; do
        [[ "${__GIT_WORKTREE_REL[${path}]%%/*}" = "${category}" ]] && echo "${path}"
    done

    return 0
}

#######################################
# Resolves a worktree identifier (as displayed by "git::list_worktrees -r") to an
# absolute path.
# Arguments:
#   rel: the "<category>/<item>" identifier to resolve
# Outputs:
#   Writes the absolute worktree path to stdout
# Returns:
#   0 if the identifier resolves to a worktree, 1 otherwise
#######################################
function git::worktree_for() {
    local rel="${1}"

    __git::load_worktrees
    [[ ${#__GIT_WORKTREE_PATHS[@]} -eq 0 ]] && return 1

    local path

    # matched on identity rather than by rebuilding the path, so that worktrees
    # outside the worktrees dir (the main one, and any not yet migrated) resolve
    for path in "${__GIT_WORKTREE_PATHS[@]}"; do
        [[ "${__GIT_WORKTREE_REL[${path}]}" = "${rel}" ]] && echo "${path}" && return 0
    done

    return 1
}

#######################################
# Checks if the current repo uses worktrees.
#
# A repo is considered to use worktrees if it has > 1 worktree.
# Returns:
#   0 if the current repo uses worktrees, 1 otherwise 
#######################################
function git::uses_worktrees() {
    __git::load_worktrees
    [[ "${#__GIT_WORKTREE_PATHS[@]}" -gt 1 ]]
}

## worktrees: mutations ########################################################

#######################################
# Discards the memoized worktree listing, so that the next lookup reloads it.
#
# The mutations below do this themselves; this is for a caller that adds or
# removes a worktree by other means (e.g.: a repo's own tooling), and that goes
# on to read the listing afterwards.
#######################################
function git::reload_worktrees() {
    __git::invalidate_worktrees
}

#######################################
# Creates a worktree, creating its parent (category) directory if necessary.
# Arguments:
#   path: the path at which to create the worktree
#   branch: the branch to check out in the worktree
#   -n: create branch, instead of checking out an existing one
#   -s: optional, defaults to HEAD; the start point for a created branch
# Returns:
#   0 if the worktree was created, 1 otherwise
#######################################
function git::create_worktree() {
    local path="${1}" ; shift
    local branch="${1}" ; shift

    local create=""
    local start=""

    local OPTIND=1
    while getopts "ns:" opt; do
      case $opt in
        n) create="true" ;;
        s) start="${OPTARG}" ;;
        \?) ulogger error "valid flags are -ns" >&2 ; return 1 ;;
      esac
    done
    shift $((OPTIND - 1))

    mkdir -p "${path%/*}" || return 1

    local args=(worktree add)
    [[ -n "${create}" ]] && args+=(-b "${branch}")
    args+=("${path}")
    [[ -n "${create}" ]] && args+=("${start:-HEAD}") || args+=("${branch}")

    git "${args[@]}" || return 1
    __git::invalidate_worktrees
}

#######################################
# Checks if a worktree is locked, i.e.: marked by "git worktree lock" as one that
# neither a removal nor a prune may touch.
# Arguments:
#   path: the worktree to check
# Returns:
#   0 if the worktree is locked, 1 otherwise
#######################################
function __git::worktree_locked() {
    __git::load_worktrees
    [[ -n "${__GIT_WORKTREE_LOCKED[${1%/}]+x}" ]]
}

#######################################
# Checks that a worktree can be taken out from under git, i.e.: that renaming it
# away and pruning after it is safe.
#
# This is the async removal's share of the work that "git worktree remove" does
# for the sync one: it never runs there, so its refusals are made here instead.
# Arguments:
#   path: the path of the worktree to remove
#   force: non-empty to allow a worktree w/ uncommitted changes
# Returns:
#   0 if the worktree can be removed, 1 otherwise
#######################################
function __git::worktree_removable() {
    local path="${1%/}"
    local force="${2}"

    __git::load_worktrees

    if [[ -z "${__GIT_WORKTREE_REL[${path}]+x}" ]]; then
        ulogger error "'${path}' isn't a worktree of this repo" >&2
        return 1
    fi

    if [[ "${path}" = "${__GIT_MAIN_WORKTREE}" ]]; then
        ulogger error "refusing to remove '${path}': it's the repo's main worktree" >&2
        return 1
    fi

    if __git::worktree_locked "${path}"; then
        ulogger error "worktree '${path}' is locked; unlock it to remove it" >&2
        return 1
    fi

    # git refuses these however it's asked, force and all: an initialized
    # submodule's git dir lives in the worktree that's on its way out
    if [[ -n "$(git -C "${path}" submodule status 2> /dev/null | grep -v '^-' || true)" ]]; then
        ulogger error "worktree '${path}' contains initialized submodules; it can't be removed" >&2
        return 1
    fi

    if [[ -z "${force}" ]] && ! git::is_clean "${path}"; then
        ulogger error "worktree '${path}' has uncommitted changes" >&2
        return 1
    fi
}

#######################################
# Removes a worktree by renaming it aside and deleting it in the background.
#
# A rename costs the same whatever the worktree holds, so this returns once git
# has let the worktree go rather than an unlink later -- which is most of a
# removal's wall-clock for a worktree carrying installed deps (~20s to unlink the
# ~190k files of one w/ node_modules and a venv, against a rename that doesn't
# measure).
#
# The doomed copy is renamed to a hidden sibling: the rename stays on one
# filesystem, which is what makes it constant-time, and nothing lists it (git
# lists worktrees from its own records, never from a directory scan). Its
# removal outlives this process, so a failure there goes unreported: what's left
# behind is a directory that no longer belongs to the repo, not history.
# Arguments:
#   path: the path of the worktree to remove
#   force: non-empty to remove a worktree w/ uncommitted changes
# Returns:
#   0 if the worktree was renamed aside and unregistered, 1 otherwise
#######################################
function __git::remove_worktree_async() {
    local path="${1%/}"
    local force="${2}"

    __git::worktree_removable "${path}" "${force}" || return 1

    local trash="${path%/*}/.${path##*/}.trash.$$"

    # "mv" would move the worktree *into* an existing directory of that name
    # rather than fail, so the name has to be free before it's used
    if [[ -e "${trash}" ]]; then
        ulogger error "can't stage '${path}' for removal: '${trash}' already exists" >&2
        return 1
    fi

    mv "${path}" "${trash}" || return 1

    # scheduled before the prune, which can't undo the rename anyway: whatever
    # git makes of its records, the disk is reclaimed
    #
    # "nohup" so the delete outlives the shell that asked for it, and a subshell
    # so it's out of that shell's job control -- nothing here waits on it
    ( nohup rm -rf "${trash}" > /dev/null 2>&1 & )

    # the worktree's path is gone, so a prune is what unregisters it -- and it's
    # what frees the branch it held, which git won't delete while a worktree
    # still claims to hold it
    git worktree prune || return 1

    __git::invalidate_worktrees
}

#######################################
# Removes a worktree and prunes its administrative files. The worktree's branch
# is left alone.
#
# The removal is synchronous by default: "git worktree remove" unlinks every file
# in the worktree before this returns. -a instead renames the worktree aside and
# deletes it in the background, returning as soon as git has let it go (see:
# __git::remove_worktree_async) -- worth having for a worktree big enough that
# the unlink is the removal. -a identifies the worktree by git's own listing
# rather than by resolving the path, so it wants the path as git records it.
# Arguments:
#   path: the path of the worktree to remove
#   -f: remove the worktree even if it has uncommitted changes
#   -a: return once the worktree is unregistered, deleting its files in the
#       background
# Returns:
#   0 if the worktree was removed, 1 otherwise
#######################################
function git::remove_worktree() {
    local path="${1}" ; shift

    local force=""
    local async=""

    local OPTIND=1
    while getopts "fa" opt; do
      case $opt in
        f) force="true" ;;
        a) async="true" ;;
        \?) ulogger error "valid flags are -fa" >&2 ; return 1 ;;
      esac
    done
    shift $((OPTIND - 1))

    if [[ -n "${async}" ]]; then
        __git::remove_worktree_async "${path}" "${force}"
        return $?
    fi

    local args=(worktree remove)
    [[ -n "${force}" ]] && args+=(--force)

    git "${args[@]}" "${path}" || return 1
    git worktree prune

    __git::invalidate_worktrees
}
