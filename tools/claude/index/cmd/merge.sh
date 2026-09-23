#!/usr/bin/env bash

set -Eeuo pipefail


# merge -d <dest> <project-dir>...
#
# Carries the named project directories' records into <dest>'s index, so that
# transcripts that have moved don't have to be scanned again to be listed.
function cmd::merge() {
    local -r dest="${1}" ; shift
    local -a merged=()

    mapfile -t merged < <(index::merge "${dest}" "$@")

    if [[ "${#merged[@]}" -eq 0 ]]; then
        printf 'no sessions cached for the directories moved into %s\n' "${dest}"
        return 0
    fi

    printf 'merged %s index(es) into %s (%s sessions)\n' \
        "${#merged[@]}" "${dest}" "$(store::count "$(index::file_for "${dest}")")"
}
