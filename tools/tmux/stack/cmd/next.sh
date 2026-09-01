#!/usr/bin/env bash

set -Eeuo pipefail


# next [pane]
#
# Shows the next pane in a slot's stack, wrapping. No-op if the pane isn't
# stacked.
function cmd::next() {
    stack::cycle next "$(stack::target "$@")"
}
