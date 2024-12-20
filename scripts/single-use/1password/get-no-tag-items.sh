#!/usr/bin/env bash

set -Eeuo pipefail


OUT_FILE="1pw-items-no-tags.txt"

if [[ ! -f "${OUT_FILE}" ]]; then
    touch ${OUT_FILE}
fi

for ITEM_ID in $(op item list | cut -d " " -f 1 | tail --lines=+2); do
    ITEM_TAGS="$(op item get "${ITEM_ID}" --format json | jq '.tags | select(. != null) | flatten[]')"

    if [[ -n "${ITEM_TAGS}" ]]; then
        echo "item=${ITEM_ID} has tags"
        continue
    fi

    if grep "${ITEM_ID}" "${OUT_FILE}"; then
        echo  "item=${ITEM_ID} exists in ${OUT_FILE}"
        continue
    fi

    echo "logging new item w/o tags"
    echo "${ITEM_ID}" >> ${OUT_FILE}
done

