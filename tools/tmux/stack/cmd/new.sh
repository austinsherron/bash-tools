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

    read -r w h < <(stack::dims "${slot}")

    group="$(stack::group "${slot}")"
    [[ -z "${group}" ]] && group="$(stack::name_for "${slot}")"

    fresh="$(stack::spawn "${group}" "${cwd}" "${w}" "${h}")" || return 1

    stack::mark "${slot}" "${group}"
    stack::mark "${fresh}" "${group}"

    # adds are idempotent + position-preserving, so this also repairs a stack
    # whose state was lost while its panes kept their @pane_stack marks
    stack::add "${group}" "${slot}"
    stack::add "${group}" "${fresh}"
    stack::mru_touch "${group}" "${slot}"
    stack::relabel "${group}"

    # the fresh pane lands in the slot, the current pane detaches in its place
    stack::swap_in "${fresh}" "${slot}" "${group}"

    ulogger info "stacked new pane ${fresh} onto pane ${slot} (stack ${group})"
}
