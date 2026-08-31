#!/usr/bin/env bash

set -Eeuo pipefail


# new [pane] [--dir path]
#
# Opens a fresh shell in a pane's slot, in the same directory, detaching that pane
# in the stack's holding session. The window layout is unchanged.
function cmd::new() {
    local dir="" slot=""
    local cwd group fresh
    local w h

    while [[ $# -gt 0 ]]; do
      case "${1}" in
        --dir) [[ -n "${2:-}" ]] && dir="${2}" ; [[ -n "${2:-}" ]] && shift ; shift ;;
        -*) shift ;;
        *) [[ -z "${slot}" ]] && slot="${1}" ; shift ;;
      esac
    done

    [[ -z "${slot}" ]] && slot="$(tmux::pane_id)"
    cwd="${dir:-$(tmux display-message -pt "${slot}" '#{pane_current_path}')}"
    validate_dir "${cwd}" "--dir" || return 1

    read -r w h < <(__stack::dims "${slot}")

    group="$(__stack::group "${slot}")"
    [[ -z "${group}" ]] && group="$(__stack::name_for "${slot}")"

    fresh="$(__stack::spawn "${group}" "${cwd}" "${w}" "${h}")" || return 1

    __stack::mark "${slot}" "${group}"
    __stack::mark "${fresh}" "${group}"

    # adds are idempotent + position-preserving, so this also repairs a stack
    # whose state was lost while its panes kept their @pane_stack marks
    __stack::add "${group}" "${slot}"
    __stack::add "${group}" "${fresh}"
    __stack::mru_touch "${group}" "${slot}"
    __stack::relabel "${group}"

    # the fresh pane lands in the slot, the current pane detaches in its place
    __stack::swap_in "${fresh}" "${slot}" "${group}"

    ulogger info "stacked new pane ${fresh} onto pane ${slot} (stack ${group})"
}
