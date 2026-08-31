#!/usr/bin/env bash

set -Eeuo pipefail


# Refreshes the live-pane snapshot. One tmux call per invocation keeps the hot
# paths (next/prev, status) cheap; it's re-read only after a pane is killed.
function __stack::load_alive() {
    local pane

    __STACK_ALIVE=()
    __STACK_ALIVE_LOADED="true"

    while read -r pane; do
        [[ -n "${pane}" ]] && __STACK_ALIVE["${pane}"]="1"
    done < <(tmux list-panes -a -F '#{pane_id}' 2> /dev/null)
}

# Takes the snapshot if nothing has yet. Reading a store prunes whatever the
# snapshot says is dead, so an empty snapshot would empty the store -- every
# read goes through here rather than trusting callers to prime it.
function __stack::init_alive() {
    [[ -n "${__STACK_ALIVE_LOADED}" ]] && return 0
    __stack::load_alive
}

# Writes a store's live entries to stdout, oldest first, pruning dead pane ids as
# a side effect (mirroring the prune in tmux-pane-store's status).
function __stack::live() {
    local -r file="${1}"
    local pane
    local -a panes=()

    __stack::init_alive
    mapfile -t panes < <(store::list "${file}")

    for pane in "${panes[@]}"; do
        [[ -z "${pane}" ]] && continue

        if [[ -n "${__STACK_ALIVE[${pane}]:-}" ]]; then
            echo "${pane}"
        else
            store::remove "${file}" "${pane}" || true
        fi
    done
}

# Writes a stack's live panes to stdout in cycle order.
function __stack::ring() {
    __stack::live "$(__stack::file "${1}")"
}

# Writes a stack's live panes to stdout in visibility order, newest last.
function __stack::mru() {
    __stack::live "$(__stack::mru_file "${1}")"
}

# Adds a pane to a stack's ring. push is idempotent and position-preserving, so
# re-adding a pane keeps its place in the cycle order.
function __stack::add() {
    store::push "$(__stack::file "${1}")" "${2}"
}

# Moves a pane to the newest position of a stack's mru, i.e.: marks it as the
# one being looked at.
function __stack::mru_touch() {
    local -r file="$(__stack::mru_file "${1}")"

    store::remove "${file}" "${2}" || true
    store::push "${file}" "${2}"
}

# Removes a pane from both of a stack's stores.
function __stack::forget() {
    store::remove "$(__stack::file "${1}")" "${2}" || true
    store::remove "$(__stack::mru_file "${1}")" "${2}" || true
}

# Kills a pane that's already out of its stack's stores, tearing the stack down
# if it no longer holds at least two panes.
function __stack::reap() {
    local -r group="${1}" pane="${2}"
    local -a ring=()

    tmux kill-pane -t "${pane}" 2> /dev/null || true

    __stack::load_alive
    mapfile -t ring < <(__stack::ring "${group}")

    if (( ${#ring[@]} < 2 )); then
        __stack::teardown "${group}"
    else
        __stack::relabel "${group}"
    fi

    return 0
}
