#!/usr/bin/env bash

set -Eeuo pipefail

# sources:
#  * app - https://support.1password.com/install-linux/#debian-or-ubuntu
#  * cli - https://developer.1password.com/docs/cli/get-started


# NOTE: this is duplicated in the dotfiles repo: we need to install 1password and
# 1password-cli to clone this repo

if dpkg -s 1password &> /dev/null && dpkg -s 1password-cli &> /dev/null; then
    echo "[INFO] 1password and 1password-cli are already installed; exiting"
    exit 0
fi

BASE_URL="https://downloads.1password.com/linux"

KEY_URL="${BASE_URL}/keys/1password.asc"
KEY_PATH="/usr/share/keyrings/1password-archive-keyring.gpg"

PKG_TYPE="deb"
ARCH="$(dpkg --print-architecture)"
SIGNED_BY="/usr/share/keyrings/1password-archive-keyring.gpg"
PKG_URL="${BASE_URL}/debian/${ARCH}"
VERSION="stable"
BRANCH="main"

POLICY_URL="${BASE_URL}/debian/debsig/1password.pol"
POLICY_DIR="/etc/debsig/policies/AC2D62742012EA22"
POLICY_PATH="${POLICY_DIR}/1password.pol"

KEYRING_DIR="/usr/share/debsig/keyrings/AC2D62742012EA22"
KEYRING_PATH="${KEYRING_DIR}/debsig.gpg"

# add 1password apt repo key
echo "[INFO] adding 1password apt repo key"
curl -sS ${KEY_URL} | sudo gpg --dearmor --output ${KEY_PATH}

# add repo
echo "[INFO] adding 1password apt repo"
echo "${PKG_TYPE} [arch=${ARCH} signed-by=${SIGNED_BY}] ${PKG_URL} ${VERSION} ${BRANCH}" \
    | sudo tee /etc/apt/sources.list.d/1password.list

# add debsig-verify policy
echo "[INFO] adding debsig-verify policy"
sudo mkdir -p ${POLICY_DIR}
curl -sS ${POLICY_URL} | sudo tee ${POLICY_PATH}

sudo mkdir -p ${KEYRING_DIR}
curl -sS ${KEY_URL} | sudo gpg --dearmor --output ${KEYRING_PATH}

# install 1password/1password-cli
echo "[INFO] installing 1password and 1password-cli"
sudo apt update -y && sudo apt install -y 1password 1password-cli

