#!/usr/bin/env bash

set -Eeuo pipefail

source "${BASH_LIB}/api/git.sh"
source "${BASH_LIB}/utils/color.sh"

source "${BASH_TOOLS}/tools/git/_helpers/config.sh"
source "${BASH_TOOLS}/tools/git/_helpers/worktrees.sh"


#######################################
# Styles a branch for display: colored by the category of the worktree it's
# checked out in, bolded when that worktree is the current one.
# Arguments:
#   branch: the branch to style
#   category: optional; the category of the branch's worktree
#   path: optional; the path of the branch's worktree
#######################################
function view::style_branch() {
    local branch="${1}"
    local category="${2:-}"
    local path="${3:-}"

    local color=""
    local style="normal"
    local output="${branch}"

    worktrees::is_current "${path}" && style="bold"
    [[ -n "${category}" ]] && color="$(config::color_for "${category}")"
    [[ -n "${color}" ]] && output="$(style::ize "${color}" "${style}" "${output}")"

    echo "${output}"
}
