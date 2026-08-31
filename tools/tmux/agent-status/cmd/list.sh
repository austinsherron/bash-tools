#!/usr/bin/env bash

set -Eeuo pipefail


# list
#
# Prints one row per flagged pane: its state, its id and the window it colors.
function cmd::list() {
    local pane state win

    while read -r state pane; do
        [[ -z "${pane}" ]] && continue

        win="$(__window_for "${pane}")"
        echo "${state} ${pane} ${win:-?}"
    done < <(__flagged_panes)
}
