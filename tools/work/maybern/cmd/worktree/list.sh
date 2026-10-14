#!/usr/bin/env bash


# The "worktree list" command; sourced by main.sh.

## help ########################################################################

function wt::help::list() {
cat <<help
DESCRIPTION

    Lists the repo's worktrees by their "<category>/<item>" identifiers, marking
    w/ "*" those that have a local env window.

USAGE

    ${WT_USAGE[list]}

ALIASES

    $(aliases_for WT_ALIASES list)

FLAGS

    -h, --help      display this message
help
}

## command #####################################################################

function wt::list() {
    local rel

    while IFS= read -r rel; do
        if window::exists "$(window::name "${rel}")"; then
            echo "* ${rel}"
        else
            echo "  ${rel}"
        fi
    done < <(git::list_worktrees -r)
}
