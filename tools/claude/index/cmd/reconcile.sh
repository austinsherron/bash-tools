#!/usr/bin/env bash

set -Eeuo pipefail


# reconcile [-p path]
#
# Brings a directory's index in line w/ its transcripts, reporting what changed.
function cmd::reconcile() {
    local -r path="${1}"

    __reconcile "${path}"

    if [[ "${CHANGED}" -eq 0 ]]; then
        printf 'index for %s is up to date (%s sessions)\n' "${path}" "${#RECORDS[@]}"
    else
        printf 'reconciled %s: %s record(s) changed, %s sessions\n' \
            "${path}" "${CHANGED}" "${#RECORDS[@]}"
    fi
}
