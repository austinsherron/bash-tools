#!/usr/bin/env bash

set -Eeuo pipefail

source "${BASH_LIB}/args/validate.sh"
source "${BASH_LIB}/utils/exec.sh"
source "${BASH_LIB}/utils.sh"


help() {
cat <<help
DESCRIPTION

    A script used to rename old Dropbox "month" directories that don't used the format I used today:

        Old -> "Month" = April
        New -> "MM - Month" = 04 - April

ARGUMENTS

    -r|--root               the directory in which to find directories to rename

FLAGS

    -d|--dry-run            optional; if present, no state changes are made
    -i, --interactive       optional; if specified, requires confirmation before each state change
help
}

declare -A MONTHS=(
    [January]=01
    [February]=02
    [March]=03
    [April]=04
    [May]=05
    [June]=06
    [July]=07
    [August]=08
    [September]=09
    [October]=10
    [November]=11
    [December]=12
)

ROOT=""

eval "$(log-env -s type=single -s prefix=dropbox)"

trap "exec::interaction_trap" EXIT

while [[ $# -gt 0 ]]; do
    case $1 in
        -r|--root)
            ROOT="${2:-}" ; [[ -n "${2:-}" ]] && shift ; shift ;;
        -i|--interactive)
            export INTERACTIVE="true" && shift ;;
        -d|--dry-run)
            export DRY_RUN="true" && shift ;;
        *)
            ulogger error "unrecognized argument: ${1}" && exit 1
    esac
done


validate_dir "${ROOT}" "-r|--root"
ROOT="$(realpath "${ROOT%%/}")"

ulogger info "searching for month dirs in ${ROOT}"

FIND_NAME_CLAUSE="$(join_by " -o -name " "${!MONTHS[@]}")"
FIND_CMD_STR="find ${ROOT} -type d -name ${FIND_NAME_CLAUSE}"
FIND_RESULTS_FILE="$(mktemp)"

IFS=' ' read -r -a FIND_CMD <<< "${FIND_CMD_STR}"

"${FIND_CMD[@]}" > "${FIND_RESULTS_FILE}"
readarray -t FIND_RESULTS < <(cat "${FIND_RESULTS_FILE}")
NUM_RESULTS="$(wc -l < "${FIND_RESULTS_FILE}" | xargs)"

ulogger info "found $NUM_RESULTS results; full results list in ${FIND_RESULTS_FILE}"

for MONTH_PATH in "${FIND_RESULTS[@]}"; do
    MONTH_PARENT="$(dirname "${MONTH_PATH}")"
    MONTH="$(basename "${MONTH_PATH}")"

    MONTH_NUM="${MONTHS[${MONTH}]}"
    NEW_NAME="${MONTH_NUM} - ${MONTH}"

    REL_BASE="${MONTH_PARENT##"${ROOT}/"}"

    ulogger info "renaming '${REL_BASE}/${MONTH}' to '${REL_BASE}/${NEW_NAME}'"
    exec::interactive "Rename?" "mv" "${MONTH_PATH}" "${MONTH_PARENT}/${NEW_NAME}"
done

