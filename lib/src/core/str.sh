#!/usr/bin/env bash


#######################################
# Converts a string to lowercase.
# Arguments:
#   str: the string to convert
# Outputs:
#   Writes the lower-case string to stdout
# Returns:
#   0 if checksum is valid,
#   1 on validation failure or if md5sum isn't formatted properly
#   2 if function arguments aren't valid
#######################################
function str::lower() {
    validate_num_args 1 $# "str::lower" || return 2

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
    validate_num_args 1 $# "str::upper" || return 1

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
    validate_num_args 2 $# "str::endswith" || return 2

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
    validate_num_args 2 $# "str::right_pad" || return 1

    local str="${1}"
    local len="${2}"

    printf "%-${len}s" "${str}"
}

