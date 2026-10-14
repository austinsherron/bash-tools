#!/usr/bin/env bash


# The "worktree open" command; sourced by main.sh.

## help ########################################################################

function wt::help::open() {
cat <<help
DESCRIPTION

    Opens a local env window for an existing worktree, picked w/ fzf, in the
    *current* tmux session -- not on the "dev" server, where "dev local"
    commands put it. Three panes: two rooted in the worktree's backend, one in
    the worktree itself.

    Warns, but opens a window anyway, if the worktree already has one: a
    worktree can have any number of windows.

USAGE

    ${WT_USAGE[open]}

ALIASES

    $(aliases_for WT_ALIASES open)

FLAGS

    -h, --help      display this message
help
}

## command #####################################################################

function wt::open() {
    local rel ; rel="$(__wt::select "worktree")"
    [[ -n "${rel}" ]] || return 0

    local path ; path="$(__wt::resolve "${rel}")" || return 1

    window::use "${path}"
    window::exists && ulogger warn "a local env window for '${rel}' already exists"

    window::init_worktree
}
