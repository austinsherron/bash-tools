#!/usr/bin/env bash

set -Eeuo pipefail


# gc
#
# Prunes dead pane ids from every stack, tears down stacks that no longer hold at
# least two panes, and kills holding sessions w/ no stack behind them. Orphaned
# stacks--ones whose slot was destroyed--keep their panes; they're only removed 
#once they're empty or down to a single pane.
function cmd::gc() {
    local group sess
    local -a groups=() orphans=() ring=()

    mapfile -t groups < <(__stack::groups)

    for group in "${groups[@]}"; do
        # reading prunes dead pane ids from both stores
        __stack::mru "${group}" > /dev/null
        mapfile -t ring < <(__stack::ring "${group}")

        if (( ${#ring[@]} < 2 )); then
            ulogger info "tearing down stack ${group}: ${#ring[@]} pane(s) left"
            __stack::teardown "${group}"
        else
            # pruning shifts the survivors' positions in the ring
            __stack::relabel "${group}"
        fi
    done

    mapfile -t orphans < <(__stack::sessions)

    for group in "${orphans[@]}"; do
        [[ -z "${group}" ]] && continue
        __stack::has "${group}" && continue

        sess="$(__stack::session "${group}")"

        # no stack behind it--but a detached shell is still the user's shell, so
        # the session only goes away once nothing in it is running
        if tmux list-panes -s -t "=${sess}" -F '#{pane_dead}' 2> /dev/null | grep -qxF 0; then
            ulogger warn "holding session ${sess} has no stack but still has live panes; leaving it"
            continue
        fi

        ulogger info "killing orphaned holding session ${sess}"
        tmux kill-session -t "=${sess}" 2> /dev/null || true
    done
}
