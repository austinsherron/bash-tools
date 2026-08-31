#!/usr/bin/env bash

set -Eeuo pipefail


# init
#
# Drops state left behind by a previous tmux server. Pane ids are unique per
# server but not across restarts, so stores that outlive their server can flag a
# window for a pane that has nothing to do w/ an agent. The marker that tells the
# two apart is a server option, so it dies w/ the server it was set on: present
# means this is a config reload and the state is live, absent means the stores
# are the last server's and have to go.
function cmd::init() {
    local marker ; marker="$(tmux show-options -gqv "${INIT_OPT}" 2> /dev/null || true)"
    local state

    if [[ -z "${marker}" ]]; then
        for state in "${STATES[@]}"; do
            store clear "$(__store_for "${state}")" || true
        done

        ulogger info "dropped agent state left by a previous tmux server"
    fi

    tmux set-option -g "${INIT_OPT}" "1"
    cmd::paint
}
