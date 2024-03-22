#!/usr/bin/env bash

set -Eeuo pipefail

# source: https://github.com/atuinsh/atuin

if which atuin &> /dev/null; then
    echo "[INFO] atuin is already installed"
    exit 0
fi

echo "[INFO] installing atuin"
bash <(curl https://raw.githubusercontent.com/atuinsh/atuin/main/install.sh)

if [[ -z "${COMPLETION_DIR+x}" ]]; then
    echo "[WARN] unable to install atuin completions: COMPLETION_DIR is unset"
    exit 0
fi

SHELL_NAME="$(basename "${SHELL}")"

echo "[INFO] installing atuin completions for shell=${SHELL_NAME}"
atuin gen-completions --shell "${SHELL_NAME}" --out-dir "${COMPLETION_DIR}"

