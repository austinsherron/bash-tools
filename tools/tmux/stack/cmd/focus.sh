#!/usr/bin/env bash

set -Eeuo pipefail


# focus [pane]
#
# Focuses a pane. A pane detached in a stack is swapped into its stack's slot
# first, so focusing lands on the window the stack lives in -- not on the
# detached session the pane happens to be waiting in.
function cmd::focus() {
    stack::focus "$(stack::target "$@")"
}
