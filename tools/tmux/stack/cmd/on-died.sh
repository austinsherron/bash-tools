#!/usr/bin/env bash

set -Eeuo pipefail


# on-died <pane>
#
# pane-died hook entry point: a stacked pane whose shell exited is dropped from
# the stack, and -- if it held the slot -- replaced by the last-viewed pane.
function cmd::on_died() {
    local -r pane="${1:-}"
    local group

    [[ -z "${pane}" ]] && return 0

    group="$(stack::group "${pane}")"
    # harmless for any other remain-on-exit pane
    [[ -z "${group}" ]] && return 0

    if stack::is_detached "${pane}" "${group}"; then
        # died out of view; nothing to promote, no layout to preserve
        stack::forget "${group}" "${pane}"
        stack::reap "${group}" "${pane}"

        ulogger debug "dropped detached pane ${pane} from stack ${group}"
        return 0
    fi

    stack::promote "${group}" "${pane}"
}
