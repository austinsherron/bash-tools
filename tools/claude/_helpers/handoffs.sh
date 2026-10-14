#!/usr/bin/env bash

source "${BASH_LIB}/api/git.sh"


# The handoff documents a session writes for the ones that follow it (see:
# cld-save), filed one directory per repo, as plans are (see: plans): a handoff
# written from anywhere in the "bash-tools" repo lands in
# "<handoffs root>/bash-tools", whichever of that repo's worktrees wrote it.

__CLAUDE_HANDOFFS_ROOT="${CLAUDE_DATA_DIR}/handoffs"

# Handoffs were kept in one flat directory under the Claude config dir before
# they were filed per repo, and a session that writes one by hand still lands
# there, so it stays the place an unfiled handoff is found.
__CLAUDE_HANDOFFS_UNFILED="${CLAUDE_CONFIG_DIR}/handoffs"


#######################################
# Displays the root of the handoffs tree, i.e.: the directory holding every
# repo's handoffs.
#######################################
function handoffs::root() {
    echo "${__CLAUDE_HANDOFFS_ROOT}"
}

#######################################
# Displays the directory unfiled handoffs are found in, i.e.: the flat directory
# they were kept in before they were filed per repo. What
# "cld-save handoffs --sync" reads.
#######################################
function handoffs::unfiled_dir() {
    echo "${__CLAUDE_HANDOFFS_UNFILED}"
}

#######################################
# Displays the directory holding a repo's handoffs. The directory need not
# exist: a repo gets one when its first handoff is saved.
# Arguments:
#   repo: optional, defaults to the current repo; the repo whose handoffs
#         directory to display
# Returns:
#   0, or 1 if no repo was named and the cwd isn't in one
#######################################
function handoffs::dir_for() {
    local repo="${1:-}"

    [[ -n "${repo}" ]] || repo="$(git::repo_name)" || return 1

    echo "${__CLAUDE_HANDOFFS_ROOT}/${repo}"
}
