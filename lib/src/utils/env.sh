#!/usr/bin/env bash


# NOTE: functions don't validate args w/ args/validate.sh so these utils can be used there

#######################################
# Checks if the environment variable w/ the provided name exists.
# Arguments:
#   var: the name of the environment variable to read
# Outputs:
#   Prints error message to stdout depending on the current log level (see: ulogger -h)
# Returns:
#   0 if if the variable exists
#   1 if if the variable doesn't exist
#   2 if function arguments aren't valid
#######################################
function env::exists() {
    local var="${1}"
    [[ -n "${!var+x}" ]] || return 1

    return 0
}

#######################################
# Checks if the provided function exists.
# Arguments:
#   fn_name: name of the function to check
# Returns:
#   0 if the function exists, 1 otherwise
#   2 if function arguments aren't valid
#######################################
function env::fn_exists() {
    local fn_name="${1}"
    [[ $(type -t "${fn_name}") == function ]] && return 0 || return 1
}

#######################################
# Checks if the environment variable w/ the provided name is empty.
# WARN: the variable is assumed to exist.
# Arguments:
#   var: the name of the environment variable to read
# Outputs:
#   Prints error message to stdout depending on the current log level (see: ulogger -h)
# Returns:
#   0 if the variable is empty
#   1 if the variable isn't empty
#   2 if function arguments aren't valid
#######################################
function env::is_empty() {
    local var="${1}"
    [[ -z "${!var}" ]] && return 0

    return 1
}

#######################################
# Checks if the environment variable w/ the provided name exists and is not empty.
# Arguments:
#   var: the name of the environment variable to read
# Outputs:
#   Prints error message to stdout depending on the current log level (see: ulogger -h)
# Returns:
#   0 if the variable exists and is not empty
#   1 if the variable doesn't exist or is empty
#   2 if function arguments aren't valid
#######################################
function env::exists_not_empty() {
    local var="${1}"
    env::exists "${var}" && ! env::is_empty "${var}"
}

#######################################
# Alias for env::exists_not_empty.
#######################################
function env::truthy() {
    local var="${1}"
    env::exists_not_empty "${var}"
}

#######################################
# Alias for ! env::exists_not_empty.
#######################################
function env::falsy() {
    local var="${1}"
    ! env::exists_not_empty "${var}"
}

#######################################
# Reads the environment variable w/ the provided name, if it exists.
# Arguments:
#   var: the name of the environment variable to read
# Outputs:
#   Writes the value associated w/ the provided env var to stdout, if it exists
#   Prints error message to stdout depending on the current log level (see: ulogger -h)
# Returns:
#   0 if successful and if function arguments are valid
#   1 if function arguments aren't valid
#######################################
function env::get() {
    local var="${1}"
    [[ -n "${!var+x}" ]] && echo "${!var}"

    return 0
}

#######################################
# Sets the variable w/ the provided name to the provided value, if it doesn't exist (i.e.: isn't set).
# Arguments:
#   var: the name of the environment variable to read/set
#   default: the value to which to set var, if it doesn't exist
# Outputs:
#   Prints error message to stdout depending on the current log level (see: ulogger -h)
# Returns:
#   1 if function arguments aren't valid
#######################################
function env::default() {
    local var="${1}"
    local default="${2}"

    env::exists "${var}" || eval "export ${var}=\"${default}\""

    return 0
}
