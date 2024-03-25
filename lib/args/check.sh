#!/usr/bin/env bash


#######################################
# Checks that a value is one of a constrained set of values.
# Arguments:
#   val: the value to check
#   the set of values of which val must be a member to be considered valid
# Returns:
#   0 if the provided value is a member of the set of valid values, 1 otherwise
#######################################
function is_one_of() {
    local valid_vals=()
    local val="${1}"

    shift

    for valid_val in "$@"; do
        valid_vals+=("${valid_val}")
        [[ "${val}" == "${valid_val}" ]] && return 0
    done

    return 1
}

#######################################
# Checks that the provided references are executables (accessible via which).
# Arguments:
#   n references to executables to check
# Returns:
#   0 if all executables are installed, 1 otherwise
#######################################
function check_installed() {
    while [[ $# -gt 0 ]]; do
        local pkg="${1}" && shift
        ! which "${pkg}" &> /dev/null && return 1
    done

    return 0
}
