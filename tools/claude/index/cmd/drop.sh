#!/usr/bin/env bash

set -Eeuo pipefail


# drop [-p path]
#
# Removes a directory's index, and those of any directory beneath it.
function cmd::drop() {
    local -r path="${1}"

    index::drop "${path}"
    printf 'dropped the index for %s\n' "${path}"
}
