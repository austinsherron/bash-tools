#!/usr/bin/env bash

set -Eeuo pipefail


# close [pane]
#
# Promotes the last-viewed stacked pane into the slot, then kills the closing
# pane. Falls back to a plain kill-pane when the pane isn't stacked, so it's safe
# to bind over kill-pane for every pane.
function cmd::close() {
    local pane group

    pane="$(stack::target "$@")"
    group="$(stack::group "${pane}")"

    if [[ -z "${group}" ]]; then
        tmux kill-pane -t "${pane}"
        return 0
    fi

    stack::promote "${group}" "${pane}"
}
