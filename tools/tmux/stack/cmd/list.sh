#!/usr/bin/env bash

set -Eeuo pipefail


# list [pane] [--all]
#
# Prints a slot's stack, marking the visible pane. With --all, prints every
# stack, including orphans.
function cmd::list() {
    local all="" slot=""
    local group
    local -a groups=()

    while [[ $# -gt 0 ]]; do
      case "${1}" in
        -a|--all) all="true" ; shift ;;
        -*) shift ;;
        *) [[ -z "${slot}" ]] && slot="${1}" ; shift ;;
      esac
    done

    [[ -z "${slot}" ]] && slot="$(tmux::pane_id)"

    if [[ -z "${all}" ]]; then
        group="$(stack::group "${slot}")"

        if [[ -z "${group}" ]]; then
            echo "pane ${slot} isn't stacked"
            return 0
        fi

        stack::print "${group}" "${slot}"
        return 0
    fi

    mapfile -t groups < <(stack::groups)

    if (( ${#groups[@]} == 0 )); then
        echo "no stacks"
        return 0
    fi

    for group in "${groups[@]}"; do
        stack::print "${group}" "${slot}"
        echo
    done
}
