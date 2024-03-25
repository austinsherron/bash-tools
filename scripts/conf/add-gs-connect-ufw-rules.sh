#!/usr/bin/env bash


if ! which ufw &> /dev/null; then
    >&2 echo "[ERROR] ufw is not installed; exiting"
    exit 1
fi

sudo ufw allow 1716:1764/udp
sudo ufw allow 1716:1764/tcp
sudo ufw reload

