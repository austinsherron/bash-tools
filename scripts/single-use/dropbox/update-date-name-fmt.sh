#!/usr/bin/env bash

set -Eeuo pipefail

source "${LOCAL_LIB}/bash/args/validate.sh"
source "${LOCAL_LIB}/bash/log/utils.sh"
source "${LOCAL_LIB}/bash/utils/exec.sh"
source "${LOCAL_LIB}/bash/utils.sh"


help() {
cat <<help
DESCRIPTION

    A script used to rename file w/ names starting w/ dates in a format I no longer use:

        Old -> "mmddyyyy" = 04192024
        New -> "yyyymmdd" = 20240419

ARGUMENTS

    -r|--root               the directory in which to find files to rename

FLAGS

    -d|--dry-run            optional; if present, no state changes are made
    -i, --interactive       optional; if specified, requires confirmation before each state change
help
}

ROOT=""

trap "exec::interaction_trap" EXIT

eval "$(log-env -s type=single -s prefix=dropbox)"
LogFlags::process_log_flags "$@"

while [[ $# -gt 0 ]]; do
    case $1 in
        -r|--root)
            ROOT="${2:-}" ; [[ -n "${2:-}" ]] && shift ; shift ;;
        -i|--interactive)
            export INTERACTIVE="true" && shift ;;
        -d|--dry-run)
            export DRY_RUN="true" && shift ;;
        -v*|-q)
            shift ;;
        *)
            ulogger error "unrecognized argument: ${1}" && exit 1
    esac
done


validate_dir "${ROOT}" "-r|--root"

ROOT="$(realpath "${ROOT%%/}")"
FIND_RESULTS_FILE="$(mktemp)"

ulogger info "searching for file w/ names starting w/ 0 or 1 in ${ROOT}"

find "${ROOT}" -type f -name "0*" -o -name "1*" > "${FIND_RESULTS_FILE}"
readarray -t FIND_RESULTS < <(cat "${FIND_RESULTS_FILE}")
NUM_RESULTS="$(wc -l < "${FIND_RESULTS_FILE}" | xargs)"

ulogger info "found $NUM_RESULTS results; full results list in ${FIND_RESULTS_FILE}"

for FILEPATH in "${FIND_RESULTS[@]}"; do
    PARENT="$(dirname "${FILEPATH}")"
    FILENAME="$(basename "${FILEPATH}")"

    if [[ ! "${FILENAME}" =~ ^[0-1][0-9][0-3][0-9]20[0-2][0-9].*$ ]]; then
        ulogger warn "file name doesn't match desired pattern: ${FILENAME}; skipping"
        continue
    elif [[ "${FILENAME}" =~ ^([0-1][0-9][0-3][0-9]20[0-2][0-9])(.*)$ ]]; then
        DATE="${BASH_REMATCH[1]}"
        REST="${BASH_REMATCH[2]}"
        NEW_NAME="${DATE:4:8}${DATE:0:4}${REST}"
    else
        ulogger error "unexpected file name format: ${FILENAME}"
        continue
    fi

    REL_BASE="${PARENT##"${ROOT}/"}"

    ulogger info "renaming '${REL_BASE}/${FILENAME}' to '${REL_BASE}/${NEW_NAME}'"
    exec::interactive "Rename?" "mv" "${FILEPATH}" "${PARENT}/${NEW_NAME}"
done

