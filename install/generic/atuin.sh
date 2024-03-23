#!/usr/bin/env bash

set -Eeuo pipefail

# source: https://github.com/atuinsh/atuin

if which atuin &> /dev/null; then
    echo "[INFO] atuin is already installed"
    exit 0
fi

## install

echo "[INFO] installing atuin"
bash <(curl https://raw.githubusercontent.com/atuinsh/atuin/main/install.sh)

## import existing shell history

SHELL_NAME="$(basename "${SHELL}")"
SHELL_HISTORY="${HOME}/.${SHELL_NAME}_history"

[[ -z "${HISTFILE+x}" ]] && [[ -s "${SHELL_HISTORY}" ]] && export HISTFILE="${SHELL_HISTORY}"

echo "[INFO] importing history for shell=${SHELL_NAME:-?} to atuin"

if ! atuin import "${SHELL_NAME:-auto}"; then
    echo "[WARN] unable to import history for shell=${SHELL_NAME:-?} to atuin"
fi

## add completions

if [[ -z "${COMPLETION_DIR+x}" ]]; then
    echo "[WARN] unable to install atuin completions: COMPLETION_DIR is unset"
else
    echo "[INFO] installing atuin completions for shell=${SHELL_NAME}"
    atuin gen-completions --shell "${SHELL_NAME}" --out-dir "${COMPLETION_DIR}"
fi

