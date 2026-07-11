#!/usr/bin/env bash


declare -A __WORKTREE_NAME_BY_BRANCH       # branch (short) -> worktree name
declare -A __WORKTREE_PATH_BY_BRANCH       # branch (short) -> worktree path

__WORKTREES_LOADED=""


function __worktrees::init() {
    [[ -n "${__WORKTREES_LOADED}" ]] && return 0
    __WORKTREES_LOADED="true"

    while IFS= read -r line; do
        local branch
        local worktree_name
        local worktree_path="${line%% *}"

        [[ "${line##* }" =~ \[([^]]+)\] ]] && branch="${BASH_REMATCH[1]}"
        [[ -z "${branch:-}" ]] && continue

        worktree_name="$(basename "${worktree_path}")"
        __WORKTREE_NAME_BY_BRANCH["${branch}"]="${worktree_name}"
        __WORKTREE_PATH_BY_BRANCH["${branch}"]="${worktree_path}"
    done < <(git worktree list)
}

function worktrees::name_for() {
    __worktrees::init
    echo "${__WORKTREE_NAME_BY_BRANCH[${1}]:-}"
}

function worktrees::path_for() {
    __worktrees::init
    echo "${__WORKTREE_PATH_BY_BRANCH[${1}]:-}"
}

function worktrees::all() {
    __worktrees::init
    local -n out="${1}"
    out=("${__WORKTREE_NAME_BY_BRANCH[@]}")
}

function worktrees::is_current() {
    local worktree="${1}"
    [[ "${worktree}" = "$(git::worktree_name)" ]]
}
