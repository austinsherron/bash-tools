#!/usr/bin/env bash

#######################################
# Joins arguments 2-n by first argument.
# Source: https://stackoverflow.com/questions/1527049/how-can-i-join-elements-of-a-bash-array-into-a-delimited-string
# Arguments:
#   sep: optional; string to use to join elements
#   optional; n strings to join w/ sep
# Outputs:
#   Writes joined string to stdout
#######################################
function _join() {
    local sep=${1-} f=${2-}

    if shift 2; then
        printf %s "$f" "${@/#/$sep}"
    fi
}
