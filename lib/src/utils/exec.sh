#!/usr/bin/env bash

source "${BASH_LIB}/args/validate.sh"
source "${BASH_LIB}/utils/env.sh"
source "${BASH_LIB}/utils/input.sh"


env::default "EXEC_USE_ULOGGER" "true"

function __log_msg() {
    local msg="${1:-}"

    if [[ -z "${msg}" ]]; then
        return 0
    fi

    if env::falsy "EXEC_USE_ULOGGER" || ! check::installed ulogger; then
        echo "[INFO] ${msg}"
    else
        ulogger info "${msg}"
    fi
}

#######################################
# Conditionally executes a command based on the value of the "DRY_RUN" env var.
# Globals:
#   DRY_RUN: optional; if set and non-empty, the provided command isn't executed
# Arguments:
#   cmd: a stringified command to execute
#   msg: optional; a message to write to stdout/log, regardless of command execution
# Outputs:
#   Prints log message to stdout depending on the current log level (see: ulogger -h) and value of "EXEC_USE_ULOGGER" env var.
# Returns:
#   The return code of the provided command, or 0 if it's not executed
#######################################
function exec::dryrun() {
    local show="${1}"; shift
    local cmd=("$@")

    if ! env::exists_not_empty "DRY_RUN"; then
        "${cmd[@]}"
    elif test "${show}" == "true"; then
        echo "${cmd[*]}"
    fi
}

#######################################
# Conditionally executes a command based the value of the "INTERACTIVE" env var and the user's prompt response.
# Responses and corresponding behaviors include:
#   (y)es - executes the provided command (respecting "DRY_RUN")
#   (Y)es to all - executes the provided command and clears the "INTERACTIVE" flag (respecting "DRY_RUN")
#   (n)o - does not execute the provided command
#   (N)o to all - does not execute the provided command and exit w/ rc=CONFIRM_RC_NO_ALL (from utils.sh); intended for use w/ exec::interactive_trap
#
# NOTE: command execute respects the "DRY_RUN" env var.
#
# Globals:
#   INTERACTIVE: optional; if set and non-empty, the user is prompted for confirmation before the provided command is executed
#   DRY_RUN: optional; if set and non-empty, the provided command isn't executed
# Arguments:
#   prompt: the interaction prompt message
#   cmd: a stringified command to execute
#   msg: optional; a message to write to stdout/log if the user responds "y"/"Y"
# Outputs:
#   Prints the interaction prompt message to stdout, depending on the value of the "INTERACTIVE" env var
#   Prints log message to stdout depending on the current log level (see: ulogger -h) and value of "EXEC_USE_ULOGGER" env var.
# Returns:
#   utils.sh > CONFIRM_RC_NO, if "INTERACTIVE" is set and non-empty and the user responds "n"
#   The return code of the provided command, or 0 if it's not executed
#######################################
function exec::interactive() {
    local prompt="${1}" ; shift
    local cmd=("$@")

    if env::exists_not_empty "INTERACTIVE"; then
        { input::global_confirm "${prompt}"; local rc=$?; }

        [[ $rc -eq $CONFIRM_RC_YES_ALL ]] && export INTERACTIVE=""
        [[ $rc -eq $CONFIRM_RC_NO ]] && return $rc
        [[ $rc -eq $CONFIRM_RC_NO_ALL ]] && exit $rc
    fi

    exec::dryrun "-" "${cmd[@]}"
}

#######################################
# Intended for use w/ "EXIT" traps to catch exits caused by answering "no to all" to an interaction prompt.
# Outputs:
#   Prints exit message to stdout depending on the current log level (see: ulogger -h) and value of "EXEC_USE_ULOGGER" env var.
#######################################
function exec::interaction_trap() {
    local rc=$?

    if [[ $rc -eq $CONFIRM_RC_NO_ALL ]]; then
        __log_msg "\"No to all\" selected; exiting"
        exit 0
    fi
}

