#!/usr/bin/env bash

set -Eeuo pipefail


# status [pane]
#
# Prints "M of N" for a stacked pane and nothing for any other. The same string
# is kept on each stacked pane as the "@stack_pos" option, which is what
# pane-border-format renders -- this is for scripting and for the status bar.
function cmd::status() {
    local pane group
    local -a ring=()
    local -i i n

    pane="$(stack::target "$@")"
    group="$(stack::group "${pane}")"
    [[ -z "${group}" ]] && return 0

    mapfile -t ring < <(stack::ring "${group}")
    n="${#ring[@]}"
    (( n < 2 )) && return 0

    for (( i = 0; i < n; i++ )); do
        if [[ "${ring[i]}" == "${pane}" ]]; then
            echo "$(( i + 1 )) of ${n}"
            return 0
        fi
    done
}
