#!/usr/bin/env bash


#######################################
# Converts a string to lowercase.
# Arguments:
#   str: the string to convert
# Outputs:
#   Writes the lower-case string to stdout
# Returns:
#   1 if function arguments aren't valid
#######################################
function str::lower() {
    local str="${1}"
    echo "${str}" |  tr '[:upper:]' '[:lower:]'
}

#######################################
# Converts a string to uppercase.
# Arguments:
#   str: the string to convert
# Outputs:
#   Writes the upper-case string to stdout
# Returns:
#   1 if function arguments aren't valid
#######################################
function str::upper() {
    local str="${1}"
    echo "${str}" |  tr '[:lower:]' '[:upper:]'
}

#######################################
# Checks if a string ends w/ a suffix.
# Arguments:
#   str: the string to check
#   sfx: the suffix to check
# Returns:
#   0 if the string ends w/ sfx
#   1 otherwise
#   2 if function arguments aren't valid
#######################################
function str::endswith() {
    local str="${1}"
    local sfx="${2}"

    [[ "${str}" == *"${sfx}" ]] && return 0 || return 1
}

#######################################
# Right pads w/ spaces the provided string to len.
# Arguments:
#   str: the string to right pad
#   len: the desired length of the output string
# Outputs:
#   The padded string
# Returns:
#   1 if function arguments aren't valid
#######################################
function str::right_pad() {
    local str="${1}"
    local len="${2}"

    printf "%-${len}s" "${str}"
}

#######################################
# Joins arguments 2-n by first argument.
# Source: https://stackoverflow.com/questions/1527049/how-can-i-join-elements-of-a-bash-array-into-a-delimited-string
# Arguments:
#   sep: optional; string to use to join elements
#   optional; n strings to join w/ sep
# Outputs:
#   Writes joined string to stdout
#######################################
function str::join() {
    local sep=${1-} f=${2-}

    if shift 2; then
        printf %s "$f" "${@/#/$sep}"
    fi
}
