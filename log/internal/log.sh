#!/usr/bin/env bash
# shellcheck disable=SC1091


function __check_installed() {
    while [[ $# -gt 0 ]]; do
        which "${1}" &> /dev/null || return 1
        shift
    done
}

function __do_log() {
    local level="${1}" ; shift

    if __check_installed ulogger; then
        ulogger "${level}" "$@"
    else
        local -r level="$(echo "${level}" |  tr '[:lower:]' '[:upper:]')"
        echo "[${level}] $*"
    fi
}

function log::trace() { __do_log "trace" "$@"; }
function log::debug() { __do_log "debug" "$@"; }
function log::info() { __do_log "info" "$@"; }
function log::warn() { __do_log "warn" "$@"; }
function log::error() { __do_log "error" "$@"; }

