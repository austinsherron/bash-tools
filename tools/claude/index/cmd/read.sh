#!/usr/bin/env bash

set -Eeuo pipefail


# read [-p path]
#
# Emits "<date>\t<session>\t<branch>\t<title>" for each titled session. Untitled
# sessions are held in the index--that's what keeps them from being rescanned--but
# never displayed.
function cmd::read() {
    local -r path="${1}"
    local id record branch title

    __reconcile "${path}"

    for id in "${!RECORDS[@]}"; do
        [[ -n "${DATES[${id}]+x}" ]] || continue

        record="${RECORDS[${id}]}"
        branch="${record%%$'\t'*}"
        title="${record#*$'\t'}"
        title="${title#*$'\t'}"

        [[ -z "${title}" ]] && continue

        printf '%s\t%s\t%s\t%s\n' "${DATES[${id}]}" "${id}" "${branch:--}" "${title}"
    done
}
