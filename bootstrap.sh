#!/usr/bin/env bash

set -euo pipefail

REPO_URL="https://github.com/obslove/arch-postinstall-apps.git"
TMP_DIR="$(mktemp -d)"

cleanup() {
  rm -rf "$TMP_DIR"
}

trap cleanup EXIT

sudo pacman -Syu --needed --noconfirm git
git clone "$REPO_URL" "$TMP_DIR/repo"
cd "$TMP_DIR/repo"
exec bash install.sh
