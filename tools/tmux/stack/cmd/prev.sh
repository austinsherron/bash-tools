#!/usr/bin/env bash

set -Eeuo pipefail


# prev [pane]
#
# Shows the previous pane in a slot's stack, wrapping. No-op if the pane isn't
# stacked.
function cmd::prev() {
    __stack::cycle prev "$(__stack::target "$@")"
}
