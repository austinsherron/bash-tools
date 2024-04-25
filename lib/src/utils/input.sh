#!/usr/bin/env bash


export CONFIRM_RC_YES=0
export CONFIRM_RC_YES_ALL=1
export CONFIRM_RC_NO=2
export CONFIRM_RC_NO_ALL=3

#######################################
# An stdout confirmation prompt.
# Arguments:
#   prompt: optional, defaults to "Are you sure?"; the prompt string
# Returns:
#   0 if the user selects "y" (yes)
#   1 if the user selects "Y" (yes to all)
#######################################
function input::confirm() {    local prompt="${1:-Are you sure?}"
    local full_prompt="${prompt} [y/n] "

    echo -n "${full_prompt}"
    read -p -n 1 -r
    local rc=1

    [[ $REPLY =~ ^[y]$ ]] && rc=$CONFIRM_RC_YES
    [[ $REPLY =~ ^[Y]$ ]] && rc=$CONFIRM_RC_YES_ALL

    echo
    return $rc

}

#######################################
# An stdout confirmation prompt w/ "global" responses, i.e.: "yes to all" and "no to all".
# Arguments:
#   prompt: optional, defaults to "Are you sure?"; the prompt string
# Returns:
#   0 if the user selects "y" (yes)
#   1 if the user selects "Y" (yes to all)
#   2 if the user selects "n" (no)
#   3 if the user selects "N" (no to all)
#######################################
function input::global_confirm() {
    local prompt="${1:-Are you sure?}"
    local full_prompt="${prompt} [y/n/Y/N] "

    echo -n "${full_prompt}"
    read -p "" -n 1 -r
    local rc=1

    [[ $REPLY =~ ^[y]$ ]] && rc=$CONFIRM_RC_YES
    [[ $REPLY =~ ^[Y]$ ]] && rc=$CONFIRM_RC_YES_ALL
    [[ $REPLY =~ ^[n]$ ]] && rc=$CONFIRM_RC_NO
    [[ $REPLY =~ ^[N]$ ]] && rc=$CONFIRM_RC_NO_ALL

    echo
    return $rc
}

