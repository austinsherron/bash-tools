#!/usr/bin/env bash

source "${BASH_LIB}/api/git.sh"


# A "stack" is a line of branches, each built on the one before it, that sits on
# top of a base branch (e.g. "master"). Nothing records the links: a branch is in
# the stack when its tip commit lies b/w the base and the stack's topmost branch
# (its "tip"), which is exactly the set "git rebase --update-refs" moves.


#######################################
# Finds the tip of the stack a branch belongs to: the branch that the given
# branch, and every branch built on it, lead up to.
#
# When several branches point at the tip commit, the given branch is preferred,
# then the first by name.
# Arguments:
#   branch: a branch in the stack
#   base: the branch the stack is built on; never part of the stack
#   out: the name of the variable to assign the tip to
# Returns:
#   0 if the tip was found, 1 if the stack forks (i.e.: has several tips), in
#   which case the forked tips are logged
#######################################
function stack::tip() {
    local branch="${1}"
    local base="${2}"
    local -n __stack_tip_out="${3}"

    local containing=()
    local candidates=()
    local b

    git::branches_containing "${branch}" containing

    for b in "${containing[@]}"; do
        [[ "${b}" = "${base}" ]] && continue
        candidates+=("${b}")
    done

    # the candidates' independent commits are those no other candidate contains,
    # i.e.: the stack's tips
    local -A tips=()
    local sha
    while IFS= read -r sha; do
        tips["${sha}"]="true"
    done < <(git merge-base --independent "${candidates[@]}")

    local tip_branches=()
    for b in "${candidates[@]}"; do
        [[ -n "${tips[$(git rev-parse "${b}")]+x}" ]] && tip_branches+=("${b}")
    done

    if [[ ${#tips[@]} -gt 1 ]]; then
        ulogger error "the stack containing '${branch}' forks into several tips:"
        for b in "${tip_branches[@]}"; do
            ulogger error "    ${b}"
        done
        return 1
    fi

    __stack_tip_out="${tip_branches[0]}"
    for b in "${tip_branches[@]}"; do
        [[ "${b}" = "${branch}" ]] && __stack_tip_out="${b}"
    done

    return 0
}

#######################################
# Copies the branches in the stack below (and including) a tip into the caller's
# array, ordered from the bottom of the stack to its tip.
# Arguments:
#   tip: the tip of the stack
#   base: the branch the stack is built on
#   out: the name of the array to populate
#######################################
function stack::branches() {
    git::branches_in_range "${2}" "${1}" "${3}"
}

#######################################
# Copies the branches that fork off a stack, rather than building on its tip, into
# the caller's array. A rebase of the stack leaves these behind on the stack's old
# commits.
# Arguments:
#   tip: the tip of the stack
#   base: the branch the stack is built on
#   out: the name of the array to populate
#######################################
function stack::forks() {
    local tip="${1}"
    local base="${2}"
    local -n __stack_forks_out="${3}"

    __stack_forks_out=()

    local branch fork_point

    # a branch forks off the stack when it shares a commit w/ the stack that the
    # base doesn't have, i.e.: its fork point w/ the tip lies w/in the stack. The
    # fork point can be any stack commit, not just a stack branch's tip, so
    # checking which branches contain a stack branch would miss some
    while IFS= read -r branch; do
        [[ "${branch}" = "${base}" ]] && continue
        git::is_ancestor "${branch}" "${tip}" && continue

        fork_point="$(git merge-base "${branch}" "${tip}")" || continue
        git::is_ancestor "${fork_point}" "${base}" && continue

        __stack_forks_out+=("${branch}")
    done < <(git for-each-ref --format='%(refname:short)' refs/heads/)
}

#######################################
# Finds the branch directly below a branch in its stack: the topmost stack branch
# beneath it that isn't at the same commit.
# Arguments:
#   branch: a branch in the stack
#   base: the branch the stack is built on
#   out: the name of the variable to assign the parent to; assigned <base> when
#        the branch is at the bottom of the stack
#######################################
function stack::parent() {
    local branch="${1}"
    local base="${2}"
    local -n __stack_parent_out="${3}"

    local below=()
    local sha b

    stack::branches "${branch}" "${base}" below
    sha="$(git rev-parse "${branch}")"

    __stack_parent_out="${base}"
    for b in "${below[@]}"; do
        [[ "$(git rev-parse "${b}")" != "${sha}" ]] && __stack_parent_out="${b}"
    done

    return 0
}

#######################################
# Finds the commit a branch was built on top of another at: the newest commit the
# other branch has pointed at -- now, or in the past per its reflog -- that the
# branch contains. Unlike a plain merge base, this finds the other branch's old
# tip even after its commits were amended or rebased. Falls back to the merge base
# when the reflog doesn't reach back far enough.
# Arguments:
#   branch: the branch built on top
#   onto: the branch it was built on
#   out: the name of the variable to assign the fork point to
# Returns:
#   0 if the fork point was found, 1 if the branches share no history
#######################################
function stack::fork_point() {
    local branch="${1}"
    local onto="${2}"
    local -n __stack_fork_point_out="${3}"

    __stack_fork_point_out="$(git merge-base --fork-point "${onto}" "${branch}" 2> /dev/null)" ||
        __stack_fork_point_out="$(git merge-base "${onto}" "${branch}" 2> /dev/null)" ||
        return 1
}

#######################################
# Copies the branches built on top of a stack branch -- on its current commits or
# on past ones (see: stack::fork_point) -- into the caller's array. A branch is
# built on the stack branch when it forked off it above the stack branch's parent.
# Arguments:
#   branch: a branch in the stack
#   parent: the branch directly below it (see: stack::parent)
#   out: the name of the array to populate
#######################################
function stack::built_on() {
    local branch="${1}"
    local parent="${2}"
    local -n __stack_built_on_out="${3}"

    __stack_built_on_out=()

    local b fork_point

    while IFS= read -r b; do
        [[ "${b}" = "${branch}" ]] && continue
        git::is_ancestor "${b}" "${branch}" && continue

        stack::fork_point "${b}" "${branch}" fork_point || continue
        git::is_ancestor "${fork_point}" "${parent}" && continue

        __stack_built_on_out+=("${b}")
    done < <(git for-each-ref --format='%(refname:short)' refs/heads/)
}
