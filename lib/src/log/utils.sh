#!/usr/bin/env bash

source "${BASH_LIB}/args/check.sh"
source "${BASH_LIB}/core/str.sh"


## flags #######################################################################

#######################################
# Checks if the provided value is a ulogger verbosity flag, i.e.: -q+ or -v+.
# Arguments:
#   value: the value to check
# Returns:
#   0 if the provided value is a ulogger verbosity flag, 1 otherwise
#######################################
function LogFlags::is_verbosity_flag() {
    local value="${1}"

    [[ "${value}" =~ ^-q+$ ]] || [[ "${value}" =~ ^-v+$ ]]
}

#######################################
# Checks if the provided value is the ulogger "verbose" flag, i.e.: --verbose.
# NOTE: the "verbose" flag is deprecated, and should be removed in favor of "verbosity" flags.
#
# Arguments:
#   value: the value to check
# Returns:
#   0 if the provided value is the ulogger verbose flag, 1 otherwise
#######################################
function LogFlags::is_verbose_flag() {
    local value="${1}"

    [[ "${value}" == "--verbose" ]]
}

#######################################
# Checks if the provided value is a ulogger flag.
# Arguments:
#   value: the value to check
# Returns:
#   0 if the provided value is a ulogger flag, 1 otherwise
#######################################
function LogFlags::is_log_flag() {
    local value="${1}"

    LogFlags::is_verbosity_flag "${value}" || LogFlags::is_verbose_flag "${value}"
}

#######################################
# Parses a ulogger verbosity flag into a value valid for the "ULOGGER_LEVEL_XFM" env var.
# Arguments:
#   flag: the flag to parse
# Returns:
#   1 if the provided value is not a valid ulogger verbosity flag
#######################################
function LogFlags::parse_verbosity_flag() {
    local flag="${1##-}"

    if [[ "${flag}" =~ ^v+$ ]]; then
        echo "+${#flag}"
    elif [[ "${flag}" =~ ^q+$ ]]; then
        echo "-${#flag}"
    else
        echo "[ERROR] unrecognized verbosity modifier: -${flag}"
        return 1
    fi
}

#######################################
# Parses a ulogger verbosity flag and exports it in the "ULOGGER_LEVEL_XFM" env var.
# Globals:
#   Sets the "ULOGGER_LEVEL_XFM" env var
# Arguments:
#   flag: the flag to parse
# Returns:
#   1 if the provided value is not a valid ulogger verbosity flag
#######################################
function LogFlags::set_verbosity_flag() {
    local flag="${1}"
    local -r level_xfm="$(LogFlags::parse_verbosity_flag "${flag}")" || return 1

    export ULOGGER_LEVEL_XFM="${level_xfm}"
}

#######################################
# Sets the "ULOGGER_VERBOSE" env var to "true".
# Globals:
#   Sets the "ULOGGER_VERBOSE" env var
#######################################
function LogFlags::set_verbose_flag() {
    export ULOGGER_VERBOSE="true"
}

#######################################
# Sets the ulogger env var for the provided flag.
# Globals:
#   Sets the "ULOGGER_LEVEL_XFM"/"ULOGGER_VERBOSE" env vars
# Arguments:
#   value: the flag to process
#   strict: optional; if truthy (i.e.: non-empty), rc is non-zero if the provided value is not a valid ulogger verbosity flag
# Returns:
#   1 if strict is truthy and the provided value is not a valid ulogger verbosity flag
#######################################
function LogFlags::process_log_flag() {
    local value="${1}"
    local strict="${2:-}"

    if LogFlags::is_verbosity_flag "${value}"; then
        LogFlags::set_verbosity_flag "${value}" || return 1
    elif LogFlags::is_verbose_flag "${value}"; then
        LogFlags::set_verbose_flag "${value}"
    elif [[ -n "${strict}" ]]; then
        echo "[ERROR] unrecognized ulogger flag: ${value}"
        return 1
    fi
}

#######################################
# Sets the ulogger env vars for the ulogger flags in the provided arguments. Arguments unrelated to ulogger are ignored.
# Globals:
#   Sets the "ULOGGER_LEVEL_XFM"/"ULOGGER_VERBOSE" env vars
# Arguments:
#   all script/function arguments that should be parsed
# Returns:
#   1 if a ulogger flag is in an invalid format
#######################################
function LogFlags::process_log_flags() {
    while [[ $# -gt 0 ]]; do
        LogFlags::process_log_flag "${1}" || return 1 ; shift
    done
}

## env #########################################################################

function exec_log_env() {
    local flag="${1}" ; shift
    local cmd=("log-env")

    while [[ $# -gt 0 ]]; do
        cmd+=("${flag}" "${1}") ; shift
    done

    # NOTE: hacky way to ensure cmd is executed correctly
    if [[ "${flag}" == "-r" ]]; then
        "${cmd[@]}"
    else
        eval "$("${cmd[@]}")"
    fi
}

#######################################
# Wraps "log-env --read".
# Arguments:
#   All arguments are passed to log-env as arguments to "-r|--read".
#######################################
function LogEnv::read() {
    local args=("$@")

    [[ ${#args[@]} -eq 0 ]] && args=("all")

    exec_log_env -r "${args[@]}"
}

#######################################
# Wraps "log-env --set".
# Arguments:
#   All arguments are passed to log-env as arguments to "-s|--set".
#######################################
function LogEnv::set() {
    exec_log_env -s "$@"
}

#######################################
# Wraps "log-env --clear".
# Arguments:
#   All arguments are passed to log-env as arguments to "-c|--clear".
#######################################
function LogEnv::clear() {
    local args=("$@")

    [[ ${#args[@]} -eq 0 ]] && args=("all")

    exec_log_env -c "${args[@]}"
}

