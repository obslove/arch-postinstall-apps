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
LOG_FILE="${POSTINSTALL_LOG_FILE:-$HOME/Backups/arch-postinstall.log}"
OPEN_ZEN_TABS="${OPEN_ZEN_TABS:-0}"
REPLACE_GITHUB_SSH_KEYS="${REPLACE_GITHUB_SSH_KEYS:-1}"
RETRY_ATTEMPTS="${RETRY_ATTEMPTS:-3}"
RETRY_DELAY_SECONDS="${RETRY_DELAY_SECONDS:-5}"

official_packages=()
aur_packages=()
official_failed=()
aur_failed=()
packages=()
aur_helper=""

ensure_not_root() {
  if [[ "${EUID:-$(id -u)}" -eq 0 ]]; then
    echo "Erro: rode este script como usuario normal, nao como root." >&2
    exit 1
  fi
}

init_logging() {
  if [[ "${POSTINSTALL_LOG_INITIALIZED:-0}" == "1" ]]; then
    return
  fi

  mkdir -p "$(dirname "$LOG_FILE")"
  touch "$LOG_FILE"

  export POSTINSTALL_LOG_FILE="$LOG_FILE"
  export POSTINSTALL_LOG_INITIALIZED=1

  exec > >(tee -a "$LOG_FILE") 2>&1
  echo "Log: $LOG_FILE"
}

retry() {
  local attempt=1
  local exit_code=0

  while true; do
    if "$@"; then
      return 0
    else
      exit_code=$?
    fi

    if (( attempt >= RETRY_ATTEMPTS )); then
      return "$exit_code"
    fi

    echo "Tentativa $attempt/$RETRY_ATTEMPTS falhou. Repetindo em ${RETRY_DELAY_SECONDS}s: $*"
    sleep "$RETRY_DELAY_SECONDS"
    attempt=$((attempt + 1))
  done
}

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

  if ! multilib_enabled; then
    echo "Erro: nao foi possivel habilitar multilib automaticamente." >&2
    exit 1
  fi

  sudo pacman -Syy --noconfirm
}

optimize_mirrors() {
  local current_mirrorlist="/etc/pacman.d/mirrorlist"
  local backup_mirrorlist
  local temp_mirrorlist

  if ! command -v reflector >/dev/null 2>&1; then
    echo "Instalando reflector..."
    retry sudo pacman -S --needed --noconfirm reflector
  fi

  echo "Atualizando mirrorlist com reflector..."
  backup_mirrorlist="$(mktemp)"
  temp_mirrorlist="$(mktemp)"

  sudo cp "$current_mirrorlist" "$backup_mirrorlist"
  if retry reflector --latest 20 --protocol https --sort rate --save "$temp_mirrorlist"; then
    sudo install -m 644 "$temp_mirrorlist" "$current_mirrorlist"
  else
    echo "Aviso: reflector falhou. Restaurando mirrorlist anterior."
    sudo install -m 644 "$backup_mirrorlist" "$current_mirrorlist"
    rm -f "$backup_mirrorlist" "$temp_mirrorlist"
    return 1
  fi

  rm -f "$backup_mirrorlist" "$temp_mirrorlist"
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

build_yay() {
  local yay_dir="$1"

  (
    cd "$yay_dir"
    makepkg -si --noconfirm
  )
}

install_yay() {
  local tmp_dir
  local status=0

  tmp_dir="$(mktemp -d)"

  echo "Instalando yay..."
  retry sudo pacman -S --needed --noconfirm base-devel git
  retry git clone https://aur.archlinux.org/yay.git "$tmp_dir/yay"
  if retry build_yay "$tmp_dir/yay"; then
    aur_helper="yay"
  else
    status=$?
  fi

  rm -rf "$tmp_dir"
  return "$status"
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
    if retry sudo pacman -S --needed --noconfirm "$package"; then
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
    if retry "$aur_helper" -S --needed --noconfirm "$package"; then
      continue
    fi

    aur_failed+=("$package")
  done
}

print_summary() {
  echo
  echo "Concluido."
  echo "Log: $LOG_FILE"
  echo "Pacman: ${official_packages[*]:-nenhum}"
  echo "AUR: ${aur_packages[*]:-nenhum}"
  echo "Falhas pacman: ${official_failed[*]:-nenhuma}"
  echo "Falhas AUR: ${aur_failed[*]:-nenhuma}"
}

open_zen_tabs() {
  if [[ "$OPEN_ZEN_TABS" != "1" ]]; then
    return
  fi

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
  local codex_path_line="export PATH=\"\$HOME/Codex/bin:\$PATH\""

  require_command npm

  echo "Configurando npm prefix em $HOME/Codex..."
  npm config set prefix "$HOME/Codex"

  if [[ ! -f "$BASHRC_FILE" ]]; then
    touch "$BASHRC_FILE"
  fi

  if ! grep -qxF "$codex_path_line" "$BASHRC_FILE"; then
    printf '\n%s\n' "$codex_path_line" >>"$BASHRC_FILE"
  fi

  export PATH="$HOME/Codex/bin:$PATH"

  echo "Instalando Codex CLI em $HOME/Codex..."
  retry npm install -g @openai/codex
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
  local current_key
  local current_key_id=""
  local key_id
  local key_title

  current_key="$(<"${SSH_KEY_PATH}.pub")"
  while IFS=$'\t' read -r key_id key_value; do
    [[ -n "$key_id" ]] || continue
    if [[ "$key_value" == "$current_key" ]]; then
      current_key_id="$key_id"
      break
    fi
  done < <(gh api user/keys --jq '.[] | [.id, .key] | @tsv')

  if [[ "$REPLACE_GITHUB_SSH_KEYS" != "1" && -n "$current_key_id" ]]; then
    echo "Chave SSH atual ja esta cadastrada no GitHub."
    return
  fi

  key_title="$(hostname)-arch-postinstall-apps"
  if [[ -z "$current_key_id" ]]; then
    echo "Enviando chave SSH para o GitHub..."
    current_key_id="$(gh api user/keys --method POST -f "title=$key_title" -f "key=$current_key" --jq '.id')"
  else
    echo "Chave SSH atual ja existe no GitHub."
  fi

  if [[ "$REPLACE_GITHUB_SSH_KEYS" != "1" ]]; then
    return
  fi

  echo "Removendo chaves SSH antigas do GitHub..."
  while IFS= read -r key_id; do
    [[ -n "$key_id" ]] || continue
    [[ "$key_id" == "$current_key_id" ]] && continue
    gh api --method DELETE "user/keys/$key_id"
  done < <(gh api user/keys --jq '.[].id')
}

repo_is_dirty() {
  ! git -C "$INSTALL_DIR" diff --quiet --no-ext-diff || \
    ! git -C "$INSTALL_DIR" diff --cached --quiet --no-ext-diff || \
    [[ -n "$(git -C "$INSTALL_DIR" status --porcelain --untracked-files=normal)" ]]
}

sync_repo() {
  mkdir -p "$(dirname "$INSTALL_DIR")"

  if [[ -d "$INSTALL_DIR/.git" ]]; then
    echo "Atualizando repositorio em $INSTALL_DIR..."
    git -C "$INSTALL_DIR" remote set-url origin "$REPO_HTTPS_URL"
    if repo_is_dirty; then
      echo "Aviso: repositorio local tem mudancas. Pulando atualizacao automatica."
      return
    fi

    retry git -C "$INSTALL_DIR" fetch origin
    if git -C "$INSTALL_DIR" show-ref --verify --quiet "refs/heads/$REPO_BRANCH"; then
      git -C "$INSTALL_DIR" checkout "$REPO_BRANCH"
    else
      git -C "$INSTALL_DIR" checkout -b "$REPO_BRANCH" "origin/$REPO_BRANCH"
    fi

    if ! retry git -C "$INSTALL_DIR" pull --ff-only origin "$REPO_BRANCH"; then
      echo "Aviso: nao foi possivel atualizar o repositorio local. Continuando com a copia atual."
    fi
  else
    if [[ -e "$INSTALL_DIR" ]]; then
      echo "Erro: $INSTALL_DIR ja existe e nao e um repositorio git." >&2
      exit 1
    fi

    echo "Clonando repositorio em $INSTALL_DIR..."
    retry git clone --branch "$REPO_BRANCH" --single-branch "$REPO_HTTPS_URL" "$INSTALL_DIR"
  fi
}

run_bootstrap() {
  retry sudo pacman -Syu --needed --noconfirm git

  require_command git
  sync_repo

  exec env \
    BOOTSTRAP_BRANCH="$REPO_BRANCH" \
    BOOTSTRAP_DIR="$INSTALL_DIR" \
    POSTINSTALL_LOG_FILE="$LOG_FILE" \
    POSTINSTALL_LOG_INITIALIZED=1 \
    OPEN_ZEN_TABS="$OPEN_ZEN_TABS" \
    REPLACE_GITHUB_SSH_KEYS="$REPLACE_GITHUB_SSH_KEYS" \
    RETRY_ATTEMPTS="$RETRY_ATTEMPTS" \
    RETRY_DELAY_SECONDS="$RETRY_DELAY_SECONDS" \
    bash "$INSTALL_DIR/install.sh" "$REPO_BRANCH"
}

setup_github_ssh() {
  if ! retry sudo pacman -S --needed --noconfirm github-cli openssh; then
    echo "Aviso: nao foi possivel instalar github-cli/openssh. Pulando configuracao do GitHub."
    return
  fi

  if ! command -v gh >/dev/null 2>&1 || ! command -v ssh-keygen >/dev/null 2>&1; then
    echo "Aviso: github-cli ou ssh-keygen indisponivel. Pulando configuracao do GitHub."
    return
  fi

  ensure_ssh_key
  if ! ensure_github_auth; then
    echo "Aviso: autenticacao do GitHub nao concluida. Pulando upload da chave SSH."
    return
  fi

  if ! upload_ssh_key; then
    echo "Aviso: nao foi possivel enviar a chave SSH para o GitHub."
    return
  fi

  git -C "$SCRIPT_DIR" remote set-url origin "$REPO_SSH_URL" || true
}

run_install() {
  load_packages
  create_directories
  ensure_multilib
  optimize_mirrors

  echo "Atualizando o sistema..."
  retry sudo pacman -Syu --noconfirm

  split_packages

  install_official_packages
  install_aur_packages

  if ((${#official_failed[@]} > 0 || ${#aur_failed[@]} > 0)); then
    print_summary
    exit 1
  fi

  setup_codex_cli
  setup_github_ssh
  print_summary
  open_zen_tabs
}

main() {
  init_logging
  ensure_not_root
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
