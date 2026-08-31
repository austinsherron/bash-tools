#!/usr/bin/env bash

set -Eeuo pipefail


# Writes a pane's dimensions to stdout, as "w h".
function __stack::dims() {
    tmux display-message -pt "${1}" '#{pane_width} #{pane_height}'
}

# Opens a fresh shell in a stack's holding session--creating the session if the
# stack doesn't have one yet--and writes its pane id to stdout.
function __stack::spawn() {
    local -r group="${1}" cwd="${2}" w="${3}" h="${4}"
    local -r sess="$(__stack::session "${group}")"
    local pane="" win=""

    if tmux::is_session "${sess}"; then
        read -r pane win < <(
            tmux new-window -d -t "=${sess}:" -c "${cwd}" -P -F '#{pane_id} #{window_id}'
        )
    else
        # no stack yet, or a stale one (e.g.: after a server restart)
        read -r pane win < <(
            tmux new-session -d -s "${sess}" -x "${w}" -y "${h}" -c "${cwd}" \
                -P -F '#{pane_id} #{window_id}'
        )
    fi

    if [[ -z "${pane}" ]] || [[ -z "${win}" ]]; then
        ulogger error "failed to open a pane in holding session ${sess}"
        return 1
    fi

    # detached windows are sized to the slot by hand, right before every swap
    tmux set-window-option -t "${win}" window-size manual

    echo "${pane}"
}

# Resizes the (detached) window holding a pane so the pane itself matches the
# slot's dimensions exactly--an incoming pane's app then never sees a size
# change, and so never reflows.
function __stack::resize_to_slot() {
    local -r pane="${1}" w="${2}" h="${3}"
    local win
    local -i pw=0 ph=0

    win="$(tmux display-message -pt "${pane}" '#{window_id}' 2> /dev/null)" || return 0
    [[ -z "${win}" ]] && return 0

    # a holding window never has more than one pane, so its border is pure
    # overhead--and a row of it would leave the pane a row short of the slot
    tmux set-window-option -t "${win}" pane-border-status off 2> /dev/null || true
    tmux set-window-option -t "${win}" window-size manual 2> /dev/null || true
    tmux resize-window -t "${win}" -x "${w}" -y "${h}" 2> /dev/null || true

    # window size != pane size whenever anything else is drawing chrome; correct
    # for the difference rather than trying to enumerate what might cause it
    read -r pw ph < <(__stack::dims "${pane}" 2> /dev/null) || true
    if (( pw > 0 )) && (( ph > 0 )) && { (( pw != w )) || (( ph != h )) ; }; then
        tmux resize-window -t "${win}" -x "$(( w + w - pw ))" -y "$(( h + h - ph ))" 2> /dev/null || true
    fi
}

# Attaches a detached pane to a slot, leaving the window layout untouched.
function __stack::swap_in() {
    local -r target="${1}" slot="${2}" group="${3}"
    local w h

    read -r w h < <(__stack::dims "${slot}")
    __stack::resize_to_slot "${target}" "${w}" "${h}"

    tmux swap-pane -s "${target}" -t "${slot}"
    # swap-pane doesn't leave the active pane deterministic
    tmux select-pane -t "${target}"

    __stack::mru_touch "${group}" "${target}"
    tmux refresh-client -S 2> /dev/null || true
}
