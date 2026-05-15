#!/usr/bin/env bash

source "${BASH_LIB}/args/validate.sh"
source "${BASH_LIB}/core/_shared.sh"


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
    echo "${1,,}"
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
    echo "${1^^}"
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
    _join "$@"
}

#######################################
# Strips characters from the ends of a string.
#
# Flags determine which ends are stripped. By default, -d is stripped from both 
# ends.
# Arguments:
#   -s: the characters to strip
#   -l: if provided, strip only the beginning of the string
#   -r: if provided, strip only the end of the string
#   str: the string to strip (positional)
# Outputs:
#   Writes the stripped string to stdout
#######################################
function str::strip() {
    local str
    local to_strip=" "

    local l="true"
    local r="true"

    local OPTIND=1
    while getopts "s:lr" opt; do
      case $opt in
        s) to_strip="${OPTARG}" ;;
        l) r="" ;;
        r) l="" ;;
        :) ulogger error "arg required for -s" >&2 ; return 1 ;;
        \?) ulogger error "valid flags are -slr" >&2 ; return 1 ;;
      esac
    done
    shift $((OPTIND - 1))

    str="${1-}"
    validate_required "str" "${str}"

    if [[ -z "${l}" ]] && [[ -z "${r}" ]]; then
        l="true"
        r="true"
    fi

    [[ -n "${l}" ]] && str="${str#"${to_strip}"}"
    [[ -n "${r}" ]] && str="${str%"${to_strip}"}"

    echo "${str}"
}

#######################################
# Replaces characters in the provided string.
#
# Globals:
#   str: the string in which to replace characters (positional)
#   -s: the characters to replace
#   -t: the characters w/ which to replace
# Outputs:
#   Writes the updated string to stdout
#######################################
function str::replace() {
    local str
    local source
    local target

    local OPTIND=1
    while getopts "s:t:" opt; do
      case $opt in
        s) source="${OPTARG}" ;;
        t) target="${OPTARG}" ;;
        :) ulogger error "arg required for -s/-t" >&2 ; return 1 ;;
        \?) ulogger error "valid flags are -st" >&2 ; return 1 ;;
      esac
    done
    shift $((OPTIND - 1))

    str="${1-}"

    validate_required "str" "${str}"
    validate_required "-s" "${source}"
    validate_required "-t" "${target}"

    echo "${str//"${source}"/"${target}"}"
}
