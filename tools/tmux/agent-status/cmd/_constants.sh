#!/usr/bin/env bash
# shellcheck disable=SC2034

set -Eeuo pipefail


# stores live beside tmux-store's, under the tmux state dir (stack.sh exports
# STORE_ROOT to it, and child "store"/"tmux-store" calls inherit it)
STORE_PREFIX="agent-"
# the window-local options the status formats interpolate: the entry's body, and
# the separator glyphs a powerline theme draws on either side of it
WINDOW_OPT="@agent_style"
EDGE_IN_OPT="@agent_edge_in"
EDGE_OUT_OPT="@agent_edge_out"
# the per-state style options read from the tmux config, w/ fallbacks
STYLE_OPT_PREFIX="@agent_style_"
# a server-local marker, set by "init"; its absence means the stores outlived the
# server that wrote them
INIT_OPT="@agent_status_init"
# the field separator paint reads window options back with. Deliberately not a
# tab: bash collapses runs of whitespace IFS, so a window w/ an empty option
# between two set ones would read back w/ its fields shifted
SEP=$'\001'
# reverts to the status bar's own style, so a printed indicator doesn't bleed
# into whatever the theme draws after it
RESET_STYLE="#[default]"
# sessions that exist to hold panes rather than to be worked in, and so are never
# worth naming in an indicator (see: tmux-stack, tmux-popup)
PRIVATE_SESSION_RE='^(_|popup-)'
# every state, loudest first: this is the precedence order used to pick a
# window's color and the store "goto" walks
STATES=("error" "input" "done")
# styles to use if not defined at defined at @agent_style_*
declare -A DEFAULT_STYLES=(
    [error]="#[fg=#1c1b19 bg=#f75341 bold]"
    [input]="#[fg=#1c1b19 bg=#fbb829 bold]"
    [done]="#[fg=#1c1b19 bg=#519f50 bold]"
)
