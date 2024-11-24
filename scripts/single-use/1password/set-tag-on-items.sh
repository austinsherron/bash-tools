#!/usr/bin/env bash

set -Eeuo pipefail


IN_FILE="1pw-items-no-tags.txt"
TAG="Tagless"

while IFS= read -r ITEM_ID; do
    if ! op item edit "${ITEM_ID}" tags="${TAG}"; then
        echo "Unable to edit item=${ITEM_ID}"
    fi
done < "${IN_FILE}"

