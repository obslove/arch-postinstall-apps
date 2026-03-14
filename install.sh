#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
PACKAGE_FILE="$SCRIPT_DIR/config/packages.txt"
BASHRC_FILE="$HOME/.bashrc"
REPO_HTTPS_URL="https://github.com/obslove/arch-postinstall-apps.git"
REPO_SSH_URL="git@github.com:obslove/arch-postinstall-apps.git"
REPO_BRANCH="${1:-${BOOTSTRAP_BRANCH:-main}}"
INSTALL_DIR="${BOOTSTRAP_DIR:-$HOME/Repositories/arch-postinstall-apps}"
SSH_KEY_PATH="${SSH_KEY_PATH:-$HOME/.ssh/id_ed25519}"

official_packages=()
aur_packages=()
official_failed=()
aur_failed=()
packages=()
aur_helper=""

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Erro: comando obrigatorio nao encontrado: $1" >&2
    exit 1
  fi
}

ensure_arch() {
  if [[ ! -f /etc/arch-release ]]; then
    echo "Erro: este script foi feito para Arch Linux." >&2
    exit 1
  fi
}

load_packages() {
  local line

  [[ -f "$PACKAGE_FILE" ]] || {
    echo "Erro: lista de pacotes nao encontrada em $PACKAGE_FILE" >&2
    exit 1
  }

  packages=()
  while IFS= read -r line || [[ -n "$line" ]]; do
    [[ -n "$line" ]] || continue
    [[ "$line" =~ ^[[:space:]]*# ]] && continue
    packages+=("$line")
  done <"$PACKAGE_FILE"
}

multilib_enabled() {
  awk '
    /^[[:space:]]*\[multilib\][[:space:]]*$/ { in_multilib=1; next }
    /^[[:space:]]*\[/ { in_multilib=0 }
    in_multilib && /^[[:space:]]*Include = \/etc\/pacman.d\/mirrorlist[[:space:]]*$/ { found=1 }
    END { exit(found ? 0 : 1) }
  ' /etc/pacman.conf
}

ensure_multilib() {
  if multilib_enabled; then
    echo "multilib ja esta habilitado."
    return
  fi

  echo "Habilitando multilib..."
  sudo cp /etc/pacman.conf "/etc/pacman.conf.bak.$(date +%Y%m%d%H%M%S)"
  sudo sed -i \
    '/^[[:space:]]*#\[multilib\][[:space:]]*$/,/^[[:space:]]*#Include = \/etc\/pacman.d\/mirrorlist[[:space:]]*$/ s/^[[:space:]]*#//' \
    /etc/pacman.conf
  sudo pacman -Syy --noconfirm
}

optimize_mirrors() {
  if ! command -v reflector >/dev/null 2>&1; then
    echo "Instalando reflector..."
    sudo pacman -S --needed --noconfirm reflector
  fi

  echo "Atualizando mirrorlist com reflector..."
  sudo reflector --latest 20 --protocol https --sort rate --save /etc/pacman.d/mirrorlist
}

split_packages() {
  local package

  official_packages=()
  aur_packages=()

  for package in "${packages[@]}"; do
    if pacman -Si "$package" >/dev/null 2>&1; then
      official_packages+=("$package")
    else
      aur_packages+=("$package")
    fi
  done
}

detect_aur_helper() {
  if command -v paru >/dev/null 2>&1; then
    aur_helper="paru"
    return 0
  fi

  if command -v yay >/dev/null 2>&1; then
    aur_helper="yay"
    return 0
  fi

  aur_helper=""
  return 1
}

install_yay() {
  local tmp_dir
  tmp_dir="$(mktemp -d)"

  echo "Instalando yay..."
  sudo pacman -S --needed --noconfirm base-devel git
  git clone https://aur.archlinux.org/yay.git "$tmp_dir/yay"
  (
    cd "$tmp_dir/yay"
    makepkg -si --noconfirm
  )
  rm -rf "$tmp_dir"
  aur_helper="yay"
}

ensure_aur_helper() {
  if detect_aur_helper; then
    echo "Usando helper AUR: $aur_helper"
    return
  fi

  install_yay
  echo "Usando helper AUR: $aur_helper"
}

install_official_packages() {
  local package

  if ((${#official_packages[@]} == 0)); then
    return
  fi

  echo "Instalando via pacman: ${official_packages[*]}"
  for package in "${official_packages[@]}"; do
    if sudo pacman -S --needed --noconfirm "$package"; then
      continue
    fi

    official_failed+=("$package")
  done
}

install_aur_packages() {
  local package

  if ((${#aur_packages[@]} == 0)); then
    return
  fi

  ensure_aur_helper
  echo "Instalando via AUR: ${aur_packages[*]}"
  for package in "${aur_packages[@]}"; do
    if "$aur_helper" -S --needed --noconfirm "$package"; then
      continue
    fi

    aur_failed+=("$package")
  done
}

print_summary() {
  echo
  echo "Concluido."
  echo "Pacman: ${official_packages[*]:-nenhum}"
  echo "AUR: ${aur_packages[*]:-nenhum}"
  echo "Falhas pacman: ${official_failed[*]:-nenhuma}"
  echo "Falhas AUR: ${aur_failed[*]:-nenhuma}"
}

open_zen_tabs() {
  if ! command -v zen-browser >/dev/null 2>&1; then
    return
  fi

  if [[ -z "${DISPLAY:-}" && -z "${WAYLAND_DISPLAY:-}" ]]; then
    return
  fi

  echo "Abrindo abas no Zen Browser..."
  nohup zen-browser \
    "https://chatgpt.com/" \
    "https://github.com/" \
    "https://github.com/obslove" \
    "https://github.com/obslove/arch-postinstall-apps" \
    "https://www.youtube.com/" \
    >/dev/null 2>&1 &
}

create_directories() {
  echo "Criando pastas base..."
  mkdir -p \
    "$HOME/Backups" \
    "$HOME/Codex" \
    "$HOME/Dots" \
    "$HOME/Pictures/Screenshots" \
    "$HOME/Pictures/Wallpapers" \
    "$HOME/Videos"
}

setup_codex_cli() {
  echo "Instalando nodejs e npm..."
  sudo pacman -S --needed --noconfirm nodejs npm

  require_command npm

  echo "Configurando npm prefix em $HOME/Codex..."
  npm config set prefix "$HOME/Codex"

  if [[ ! -f "$BASHRC_FILE" ]]; then
    touch "$BASHRC_FILE"
  fi

  if ! grep -qxF 'export PATH="$HOME/Codex/bin:$PATH"' "$BASHRC_FILE"; then
    printf '\nexport PATH="$HOME/Codex/bin:$PATH"\n' >>"$BASHRC_FILE"
  fi

  echo "Instalando Codex CLI..."
  npm install -g @openai/codex
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

ensure_github_auth() {
  if gh auth status >/dev/null 2>&1; then
    echo "GitHub CLI ja autenticado."
    return
  fi

  if command -v zen-browser >/dev/null 2>&1; then
    echo "Autenticando no GitHub com gh no Zen Browser..."
    BROWSER="zen-browser" gh auth login --web --git-protocol ssh
    return
  fi

  echo "Autenticando no GitHub com gh..."
  gh auth login --web --git-protocol ssh
}

upload_ssh_key() {
  local key_id
  local key_title

  echo "Removendo chaves SSH existentes do GitHub..."
  while IFS= read -r key_id; do
    [[ -n "$key_id" ]] || continue
    gh api --method DELETE "user/keys/$key_id"
  done < <(gh api user/keys --jq '.[].id')

  key_title="$(hostname)-arch-postinstall-apps"
  echo "Enviando chave SSH para o GitHub..."
  gh ssh-key add "${SSH_KEY_PATH}.pub" --title "$key_title"
}

sync_repo() {
  mkdir -p "$(dirname "$INSTALL_DIR")"

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
}

run_bootstrap() {
  sudo pacman -Syu --needed --noconfirm git

  require_command git
  sync_repo

  exec bash "$INSTALL_DIR/install.sh"
}

setup_github_ssh() {
  sudo pacman -S --needed --noconfirm github-cli openssh

  require_command gh
  require_command ssh-keygen

  ensure_ssh_key
  ensure_github_auth
  upload_ssh_key
  git -C "$SCRIPT_DIR" remote set-url origin "$REPO_SSH_URL"
}

run_install() {
  load_packages
  create_directories
  ensure_multilib
  optimize_mirrors

  echo "Atualizando o sistema..."
  sudo pacman -Syu --noconfirm

  split_packages

  install_official_packages
  install_aur_packages
  setup_codex_cli
  setup_github_ssh
  print_summary
  open_zen_tabs

  if ((${#official_failed[@]} > 0 || ${#aur_failed[@]} > 0)); then
    exit 1
  fi
}

main() {
  ensure_arch
  require_command pacman
  require_command sudo

  if [[ -f "$PACKAGE_FILE" ]]; then
    run_install
  else
    run_bootstrap
  fi
}

main "$@"
