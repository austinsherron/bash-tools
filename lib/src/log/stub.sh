#!/usr/bin/env bash

# NOTE: import src files, as these utils may be used before lib installation
source "${BASH_TOOLS}/lib/src/args/check.sh"
source "${BASH_TOOLS}/lib/src/log/level.sh"
source "${BASH_TOOLS}/lib/src/utils/env.sh"
source "${BASH_TOOLS}/lib/src/utils.sh"


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

    if check_installed ulogger; then
        ulogger "${level}" "$@"
    elif __should_log "${level}"; then
        echo "[${level}] $*"
    fi
}

function StubLogger::log() {
    local -r level="$(to_upper "${1}")" ; shift
    __do_log "${level}" "$@"
}

