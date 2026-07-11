#!/usr/bin/env bash

set -Eeuo pipefail

source "${BASH_LIB}/api/git.sh"
source "${BASH_LIB}/utils/color.sh"

source "${BASH_TOOLS}/tools/git/_helpers/config.sh"
source "${BASH_TOOLS}/tools/git/_helpers/worktrees.sh"


function view::style_branch() {
    local branch="${1}"
    local worktree="${2}"

    local color=""
    local style="normal"
    local output="${branch}"

    [[ "${worktree}" = "$(git::worktree_name)" ]] && style="bold"
    [[ -n "${worktree}" ]] && color="$(config::color_for "${worktree}")"
    [[ -n "${color}" ]] && output="$(style::ize "${color}" "${style}" "${output}")"

    echo "${output}"
}
