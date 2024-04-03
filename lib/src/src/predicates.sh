#!/usr/bin/env bash


#######################################
# Checks if the provided value is truthy (i.e.: == "true" or 0).
# Arguments:
#   val: the value to check
# Returns
#   0 if val == "true" or 0, 1 otherwise
#######################################
function is_true() {
    local val="${1}"
    [[ "${val}" == "true" ]] && return 0 || return 1
}

#######################################
# Checks if the provided value is not truthy (i.e.: != "true" or 0).
# Arguments:
#   val: the value to check
# Returns
#   0 if val != "true" or 0, 1 otherwise
#######################################
function not_true() {
    local val="${1}"
    ! is_true "${val}"
}

#######################################
# Checks if the provided value is "empty", i.e.: the empty-string (""), in contrast to "unset".
# Arguments:
#   val: the value to check
# Returns:
# 0 if the provided value is the empty-string (""), 1 otherwise
#######################################
function is_empty() {
    local val="${1}"
    [[ "${val}" == "" ]] && return 0 || return 1
}

