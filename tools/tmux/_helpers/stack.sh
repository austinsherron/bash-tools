#!/usr/bin/env bash

set -Eeuo pipefail

source "${BASH_LIB}/api/tmux.sh"
source "${BASH_LIB}/data/store.sh"
source "${BASH_LIB}/log/utils.sh"


# The mechanism behind stacked panes: a set of panes that share a single tmux
# layout slot (see: tmux-stack).
#
# tmux panes are 1:1 with layout slots--a new pane always re-tiles the window.
# A stack instead detaches every pane it isn't showing into a holding session
# ("_stack-<N>"), one window apiece, and moves panes between the slot and that
# session w/ swap-pane. swap-pane exchanges panes *between slots*, so the visible
# layout never changes.
#
# A stack is named for the pane that created it, w/out "%"--pane ids are unique
# per server and are never reused, so the name is stable and always numeric.
#
# Stack membership is the per-pane option "@pane_stack"; per-pane options travel
# w/ a pane across swap-pane, so membership is self-maintaining. Stacked panes
# also get "remain-on-exit on", so a dying shell holds its slot long enough for
# the pane-died hook to promote a replacement into it. Two more options exist for
# pane-border-format to render:
#
#   @stack_pos      the pane's place in the ring, as "M of N"
#   @stack_crumbs   every pane in the ring as a " > " trail, this pane's own entry
#                   prominent and the rest dimmed; a pane w/o a title (see:
#                   tmux-pane-title) is listed by its position instead
#
# Each pane carries its own copy of the trail, w/ itself highlighted, so cycling
# costs nothing--the trail is only rebuilt when the ring or a title changes.
# We use options rather than the real pane title because applications can overwrite
# the title.
#
# Two orderings are kept, both as stores (see: store) under "${STORE_ROOT}/stacks":
#
#   <N>       creation order; the ring "next"/"prev" cycle through
#   <N>.mru   visibility order, newest == currently visible; on close, dropping
#             the closing pane leaves the last-viewed pane newest -- the pane
#             that gets promoted into the slot
#
# Both are pruned of dead pane ids on read.

# resolved the same way as tmux-store's, so both live under the tmux state dir
export STORE_ROOT="${STORE_ROOT:-${XDG_STATE_HOME:-${HOME}/.local/state}/tmux}"

__STACK_DIR="${STORE_ROOT}/stacks"
__STACK_OPT="@pane_stack"
__STACK_POS_OPT="@stack_pos"
__STACK_CRUMBS_OPT="@stack_crumbs"
__PANE_TITLE_OPT="@pane_title"           # see: tmux-pane-title
__STACK_SESS_PREFIX="_stack-"

# a snapshot of every live pane id
declare -A __STACK_ALIVE=()

__STACK_ALIVE_LOADED=""

## parts #######################################################################

# the helpers themselves, one file per concern. They're "_"-prefixed because none
# of them is an entry point: a caller sources *this* file, which is what
# guarantees the constants above are set and the shared state declared before any
# of them runs. Order between them doesn't matter, as they only define functions.
for __stack_part in "${BASH_TOOLS}"/tools/tmux/_helpers/stack/_*.sh; do
    # shellcheck source=/dev/null
    source "${__stack_part}"
done

# sourced into the caller's scope, so don't leave the loop variable behind
unset __stack_part
