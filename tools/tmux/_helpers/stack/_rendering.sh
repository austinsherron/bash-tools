#!/usr/bin/env bash

set -Eeuo pipefail


# Prints one stack: a header, then a row per pane (marker, idx, id, cmd, cwd).
function __stack::print() {
    local -r group="${1}" current="${2:-}"
    local pane cmd cwd title marker slotted="" orphaned=""
    local -a panes=()
    local -i i=0

    mapfile -t panes < <(__stack::ring "${group}")

    for pane in "${panes[@]}"; do
        __stack::is_detached "${pane}" "${group}" || slotted="true"
    done

    # nothing of the stack is in a real window: its slot was destroyed under it
    [[ "${#panes[@]}" -gt 0 ]] && [[ -z "${slotted}" ]] && orphaned=" [orphaned]"

    printf 'stack %s (%d panes)%s\n' "${group}" "${#panes[@]}" "${orphaned}"

    for pane in "${panes[@]}"; do
        i+=1
        marker=" "
        [[ "${pane}" == "${current}" ]] && marker="*"

        cmd="$(tmux display-message -pt "${pane}" '#{pane_current_command}' 2> /dev/null || true)"
        cwd="$(tmux display-message -pt "${pane}" '#{pane_current_path}' 2> /dev/null || true)"
        title="$(tmux show-options -p -t "${pane}" -v "${__PANE_TITLE_OPT}" 2> /dev/null || true)"

        printf '%s %2d  %-6s %-14s %-14s %s\n' \
            "${marker}" "${i}" "${pane}" "${title}" "${cmd}" "${cwd/#${HOME}/\~}"
    done
}
