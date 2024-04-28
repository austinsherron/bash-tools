#!/usr/bin/env bash

source "${BASH_LIB}/args/check.sh"
source "${BASH_LIB}/log/level.sh"
source "${BASH_LIB}/utils/env.sh"


function __current_level() {
    if env::exists "CURRENT_LOG_LEVEL"; then
        env::get "CURRENT_LOG_LEVEL"
    elif env::exists "DEFAULT_LOG_LEVEL"; then
        env::get "DEFAULT_LOG_LEVEL"
    else
        echo "${LOG_LEVEL_DEFAULT}"
    fi
}

function __should_log() {
    local level="${1}"
    local -r current_level="$(__current_level)"

     LogLevel::should_log "${level}" "${current_level}"
}

function __do_log() {
    local -r level="${1}" ; shift

    if check::installed ulogger; then
        ulogger "${level}" "$@"
        return $?
    fi

    { __should_log "${level}" rc=$?; }

    if [[ $rc -gt 1 ]]; then
        # shellcheck disable=SC2086
        return $rc
    else
        echo "[${level}] $*"
    fi

    return 0
}

#######################################
# Logger wrapper for use cases in which ulogger may not be available, i.e.: before its installation.
# This function calls ulogger if it's installed, otherwise it falls back to a simplified for of stdout logging:
#   * the ulogger config file isn't used; log level is configured via "CURRENT_LOG_LEVEL"/"DEFAULT_LOG_LEVEL" env vars
#   * log msgs are to stdout only, not to files
# Arguments:
#   level: the log level of the msg
#   all other arguments are treated as log msg fragments
# Outputs:
#   The log msg, depending on various factors (i.e.: ulogger availability), log level config, etc.
#   Validation error messages
# Returns:
#   2 if an unexpected error is encountered
#######################################
function StubLogger::log() {
    local -r level="${1}" ; shift

    __do_log "${level}" "$@"
}

