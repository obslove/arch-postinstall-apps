#!/usr/bin/env bash

set -euo pipefail

REPO_URL="https://github.com/obslove/arch-postinstall-apps.git"
REPO_BRANCH="${1:-${BOOTSTRAP_BRANCH:-main}}"
TMP_DIR="$(mktemp -d)"

cleanup() {
  rm -rf "$TMP_DIR"
}

trap cleanup EXIT

if [[ ! -f /etc/arch-release ]]; then
  echo "Erro: este bootstrap foi feito para Arch Linux." >&2
  exit 1
fi

if ! command -v pacman >/dev/null 2>&1; then
  echo "Erro: pacman nao encontrado." >&2
  exit 1
fi

sudo pacman -Syu --needed --noconfirm git
git clone --branch "$REPO_BRANCH" --single-branch "$REPO_URL" "$TMP_DIR/repo"
cd "$TMP_DIR/repo"
exec bash install.sh
