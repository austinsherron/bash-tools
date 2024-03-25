#!/usr/bin/env bash


#######################################
# Checks if the provided value is a help flag, indicated by "-h" or "--help".
# Arguments:
#   flag: the value to check
# Outputs:
#   Prints error message to stdout depending on the current log level (see: ulogger -h)
# Returns:
#   0 if the provided value is "-h" or "--help", 1 otherwise
#######################################
function is_help_flag() {
    local flag="${1}"
    [[ "${flag}" == "-h" ]] || [[ "${flag}" == "--help" ]] || return 1
    return 0
}

