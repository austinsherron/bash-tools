#!/usr/bin/env bash


#######################################
# Validates that variable w/ name is non-empty.
# Arguments:
#   name: the name of the variable to validate
#   val: the value to validate
# Outputs:
#   Prints error message to stdout depending on the current log level (see: ulogger -h)
# Returns:
#   0 if val is non-empty, 1 otherwise
#######################################
function validate_required() {
    local name="${1}"
    local val="${2}"

    if [[ -z "${val}" ]]; then
        ulogger error "${name} is a required param"
        return 1
    fi
}

#######################################
# Validates that at least one provided variable is non-empty.
# Arguments:
#   n "name" "value" pairs, i.e.:
#       validate_at_least_one "-1|--one" "${ONE}" "-2|--two" "${TWO}"
# Outputs:
#   Prints error message to stdout depending on the current log level (see: ulogger -h)
# Returns:
#   0 if at least one value is non-empty, 1 otherwise
#######################################
function validate_at_least_one() {
    if [[ $(($# % 2)) -ne 0 ]]; then
        ulogger error "validate_one_required takes N pairs: the args to validate and their names/flags"
        return 2
    fi

    local names=()

    while [[ $# -gt 0 ]]; do
        [[ -n "${1}" ]] && return 0
        names+=("${2}")

        shift
        shift
    done

    local names_str
    names_str="$(echo "${names[@]}" | tr ' ' ', ')"

    ulogger error "one of ${names_str} is required"
}

#######################################
# Validates that a value is one of a constrained set of values.
# Arguments:
#   name: the name of the variable to validate
#   val: the value to validate
#   the set of values of which val must be a member to be considered valid
# Outputs:
#   Prints error message to stdout depending on the current log level (see: ulogger -h)
# Returns:
# 0 if the provided value is a member of the set of valid values, 1 otherwise
#######################################
function validate_one_of() {
    local valid_vals=()

    local name="${1}"
    local val="${2}"
    shift
    shift

    for valid_val in $@; do
        valid_vals+=("${valid_val}")
        [[ "${val}" == "${valid_val}" ]] && return 0
    done

    local valid_vals_str="$(echo "${valid_vals[*]}" | tr " " "|")"
    ulogger error "${name} must be one of '${valid_vals_str}', not '${val}'"
    erturn 1
}

#######################################
# Validates that nreq == nactual.
# Arguments:
#   nreq: the number against which to validate
#   nactual: the number to validate
# Outputs:
#   Prints error message to stdout depending on the current log level (see: ulogger -h)
# Returns:
#   0 if nreq == nactual, 1 otherwise
#######################################
function validate_num_args() {
    local nreq=$1
    local nactual=$2

    [[ $nactual -eq $nreq ]] && return 0

    local caller=""
    local arg="argument"

    [[ $# -eq 3 ]] && local caller="${3}: "
    [[ $nreq -gt 1 ]] && arg="arguments"

    ulogger error "${caller}$nreq ${arg} required but received $nactual"
    return 1
}

#######################################
# Validates that at least one of provided variables is empty.
# Arguments:
#   l: one of the variables to validate
#   lname: the name of the previous variable
#   r: the other variable to validate
#   rname: the name of the previous variable
# Outputs:
#   Prints error message to stdout depending on the current log level (see: ulogger -h)
# Returns:
#   0 if at least one of provided variables is empty, 1 otherwise
#######################################
function validate_mutually_exclusive() {
    local l="${1}"
    local lname="${2}"

    local r="${3}"
    local rname="${4}"

    if [[ -n "${l}" ]] && [[ -n "${r}" ]]; then
        ulogger error "${lname} and ${rname} are mutually exclusive"
        return 1
    fi
}

#######################################
# Validates that a path references a valid, non-empty file.
# Arguments:
#   path: the path to validate
#   name: the name of the variable to validate
# Outputs:
#   Prints error message to stdout depending on the current log level (see: ulogger -h)
# Returns:
#   0 if the provided path references a valid, non-empty file, 1 otherwise
#######################################
function validate_file() {
    local path="${1}"
    local name="${2}"

    if [[ ! -s "${path}" ]]; then
        ulogger error "${name} must refer to a valid file"
        return 1
    fi
}

#######################################
# Validates that a path references a valid directory.
# Arguments:
#   path: the path to validate
#   name: the name of the variable to validate
# Outputs:
#   Prints error message to stdout depending on the current log level (see: ulogger -h)
# Returns:
#   0 if the provided path references a valid directory, 1 otherwise
#######################################
function validate_dir() {
    local path="${1}"
    local name="${2}"

    if [[ ! -d "${path}" ]]; then
        ulogger error "${name} must refer to a valid directory"
        return 1
    fi
}
