#!/usr/bin/env bash

set -Eeuo pipefail

# source: https://github.com/dflemstr/rq/blob/master/doc/installation.md#generic


if which rq &> /dev/null; then
    echo "[INFO] rq is already installed"
    exit 0
fi

echo "[INFO] installing rq"
curl -LSfs https://japaric.github.io/trust/install.sh | sh -s -- --git dflemstr/rq

