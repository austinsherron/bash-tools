#!/usr/bin/env bash

set -Eeuo pipefail

source "${BASH_LIB}/log/utils.sh"


COUNT=0
MAX=5
declare -A IN_PROGRESS=()

IN_FILE=""
IN_DIR=""

LogFlags::process_log_flags "$@"
LogEnv::set "type=dbx" "prefix=mig"

function wait_for_download() {
    ulogger info "count=$COUNT; waiting..."
    local wait_file="??"

    { wait -p done_job -n || true; RC=$?; }

    if [[ -n "${IN_PROGRESS[${done_job}]+x}" ]]; then
        wait_file="${IN_PROGRESS[${done_job}]}"
        unset "IN_PROGRESS[${done_job}]"
    fi

    if [[ $RC -gt 0 ]]; then
        ulogger error "error waiting for file=${wait_file}"
    fi

    COUNT=$((COUNT - 1))
    ulogger debug "removing ${wait_file} from in progress=${!IN_PROGRESS[*]}"
}

while read -r FILE; do
    LOCAL="/Volumes${FILE}"
    DIR="$(dirname "${LOCAL}")"
    CLEAN="${LOCAL//*${IN_DIR}/}"
    CLEAN_DIR="$(dirname "${CLEAN}")"

    [[ -f "${LOCAL}" ]] && continue
    [[ ! -d "${DIR}" ]] && ulogger debug "mkdir ${CLEAN_DIR}" && mkdir -p "${DIR}"

    if [[ $COUNT -ge $MAX ]]; then
        wait_for_download
    fi

    ulogger info "downloading file=${CLEAN} to dir=${CLEAN_DIR}}"
    dbxcli get "${FILE}" "${DIR}" &
    IN_PROGRESS[$!]="${CLEAN}"
    ulogger debug "adding ${CLEAN} to in progress=${!IN_PROGRESS[*]}"
    COUNT=$((COUNT + 1))
done < "${IN_FILE}"

while [[ "${#IN_PROGRESS[@]}" -gt 0 ]]; do
    wait_for_download
done

