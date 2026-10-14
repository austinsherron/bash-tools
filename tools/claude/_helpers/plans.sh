#!/usr/bin/env bash

source "${BASH_LIB}/api/git.sh"


# The plans saved from Claude Code sessions (see: cld-save), filed one directory
# per repo: a plan saved from anywhere in the "bash-tools" repo lands in
# "<plans root>/bash-tools", whichever of that repo's worktrees it was saved from.

__CLAUDE_PLANS_ROOT="${CLAUDE_DATA_DIR}/plans"

# Claude Code keeps its own plans directory under the Claude config home, and a
# session told to write a plan by hand lands there too, so it -- rather than the
# flat level of the plans root, which only ever holds the per-repo directories
# -- is where an unfiled plan is found. It's a separate tree from the one plans
# are filed in, unlike the handoffs equivalent (see: handoffs).
__CLAUDE_PLANS_UNFILED="${CLAUDE_CONFIG_DIR}/plans"


#######################################
# Displays the root of the plans tree, i.e.: the directory holding every repo's
# plans.
#######################################
function plans::root() {
    echo "${__CLAUDE_PLANS_ROOT}"
}

#######################################
# Displays the directory unfiled plans are found in, i.e.: the one a plan
# written rather than saved (see: cld-save) lands in. What
# "cld-save plans --sync" reads.
#######################################
function plans::unfiled_dir() {
    echo "${__CLAUDE_PLANS_UNFILED}"
}

#######################################
# Displays the directory holding a repo's plans. The directory need not exist: a
# repo gets one when its first plan is saved.
# Arguments:
#   repo: optional, defaults to the current repo; the repo whose plans directory
#         to display
# Returns:
#   0, or 1 if no repo was named and the cwd isn't in one
#######################################
function plans::dir_for() {
    local repo="${1:-}"

    [[ -n "${repo}" ]] || repo="$(git::repo_name)" || return 1

    echo "${__CLAUDE_PLANS_ROOT}/${repo}"
}
