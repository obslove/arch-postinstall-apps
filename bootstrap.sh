#!/usr/bin/env bash

set -euo pipefail

REPO_HTTPS_URL="https://github.com/obslove/arch-postinstall-apps.git"
REPO_SSH_URL="git@github.com:obslove/arch-postinstall-apps.git"
REPO_BRANCH="${1:-${BOOTSTRAP_BRANCH:-main}}"
INSTALL_DIR="${BOOTSTRAP_DIR:-$HOME/arch-postinstall-apps}"
SSH_KEY_PATH="${SSH_KEY_PATH:-$HOME/.ssh/id_ed25519}"

ensure_arch() {
  if [[ ! -f /etc/arch-release ]]; then
    echo "Erro: este bootstrap foi feito para Arch Linux." >&2
    exit 1
  fi
}

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Erro: comando obrigatorio nao encontrado: $1" >&2
    exit 1
  fi
}

ensure_ssh_key() {
  local ssh_dir
  local key_comment

  ssh_dir="$(dirname "$SSH_KEY_PATH")"
  mkdir -p "$ssh_dir"
  chmod 700 "$ssh_dir"

  if [[ -f "$SSH_KEY_PATH" ]]; then
    echo "Chave SSH ja existe em $SSH_KEY_PATH"
    return
  fi

  key_comment="$(git config --global user.email 2>/dev/null || true)"
  if [[ -z "$key_comment" ]]; then
    key_comment="${USER}@$(hostname)"
  fi

  echo "Criando chave SSH em $SSH_KEY_PATH..."
  ssh-keygen -t ed25519 -C "$key_comment" -f "$SSH_KEY_PATH" -N ""
}

sync_repo() {
  if [[ -d "$INSTALL_DIR/.git" ]]; then
    echo "Atualizando repositorio em $INSTALL_DIR..."
    git -C "$INSTALL_DIR" remote set-url origin "$REPO_HTTPS_URL"
    git -C "$INSTALL_DIR" fetch origin
    if git -C "$INSTALL_DIR" show-ref --verify --quiet "refs/heads/$REPO_BRANCH"; then
      git -C "$INSTALL_DIR" checkout "$REPO_BRANCH"
    else
      git -C "$INSTALL_DIR" checkout -b "$REPO_BRANCH" "origin/$REPO_BRANCH"
    fi
    git -C "$INSTALL_DIR" pull --ff-only origin "$REPO_BRANCH"
  else
    if [[ -e "$INSTALL_DIR" ]]; then
      echo "Erro: $INSTALL_DIR ja existe e nao e um repositorio git." >&2
      exit 1
    fi

    echo "Clonando repositorio em $INSTALL_DIR..."
    git clone --branch "$REPO_BRANCH" --single-branch "$REPO_HTTPS_URL" "$INSTALL_DIR"
  fi

  git -C "$INSTALL_DIR" remote set-url origin "$REPO_SSH_URL"
}

print_ssh_instructions() {
  echo
  echo "Chave publica SSH:"
  cat "${SSH_KEY_PATH}.pub"
  echo
  echo "Adicione essa chave no GitHub para usar o remoto SSH."
}

main() {
  ensure_arch
  require_command pacman
  require_command sudo

  sudo pacman -Syu --needed --noconfirm git openssh

  require_command git
  require_command ssh-keygen

  ensure_ssh_key
  sync_repo
  print_ssh_instructions

  cd "$INSTALL_DIR"
  exec bash install.sh
}

main "$@"
