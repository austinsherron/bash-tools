#!/usr/bin/env bash

set -Eeuo pipefail


# anchor [pane]
#
# Prints the pane whose session/window a pane logically lives in: itself, or the
# pane holding its stack's slot when it's detached. A holding session is an
# implementation detail, not an address, so anything that names a pane's
# location to the user resolves it through here first.
function cmd::anchor() {
    stack::anchor "$(stack::target "$@")"
}
