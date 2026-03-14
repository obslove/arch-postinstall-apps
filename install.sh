#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
PACKAGE_FILE="$SCRIPT_DIR/config/packages.txt"
EXTRA_PACKAGE_FILE="$SCRIPT_DIR/config/packages-extra.txt"
BASHRC_FILE="$HOME/.bashrc"
REPO_HTTPS_URL="https://github.com/obslove/arch-postinstall-apps.git"
REPO_SSH_URL="git@github.com:obslove/arch-postinstall-apps.git"
REPO_BRANCH="${1:-${BOOTSTRAP_BRANCH:-main}}"
REPOSITORIES_DIR="${REPOSITORIES_DIR:-$HOME/Repositories}"
INSTALL_DIR="${BOOTSTRAP_DIR:-$REPOSITORIES_DIR/arch-postinstall-apps}"
YAY_REPO_DIR="${YAY_REPO_DIR:-$REPOSITORIES_DIR/yay}"
YAY_SNAPSHOT_URL="${YAY_SNAPSHOT_URL:-https://aur.archlinux.org/cgit/aur.git/snapshot/yay.tar.gz}"
SSH_KEY_PATH="${SSH_KEY_PATH:-$HOME/.ssh/id_ed25519}"
LOG_FILE="${POSTINSTALL_LOG_FILE:-$HOME/Backups/arch-postinstall.log}"
SUMMARY_FILE="${POSTINSTALL_SUMMARY_FILE:-$HOME/Backups/arch-postinstall-summary.txt}"
OPEN_ZEN_TABS="${OPEN_ZEN_TABS:-0}"
REPLACE_GITHUB_SSH_KEYS="${REPLACE_GITHUB_SSH_KEYS:-1}"
RETRY_ATTEMPTS="${RETRY_ATTEMPTS:-3}"
RETRY_DELAY_SECONDS="${RETRY_DELAY_SECONDS:-5}"
STATE_DIR="${POSTINSTALL_STATE_DIR:-${XDG_STATE_HOME:-$HOME/.local/state}/arch-postinstall-apps}"
LOCK_DIR="${POSTINSTALL_LOCK_DIR:-$STATE_DIR/lock}"
LOCK_HELD="${POSTINSTALL_LOCK_HELD:-0}"
SYSTEM_UPDATED="${POSTINSTALL_SYSTEM_UPDATED:-0}"

official_packages=()
aur_packages=()
official_failed=()
aur_failed=()
packages=()
aur_helper=""
cleanup_paths=()
verified_commands=()
missing_commands=()
version_info=()

ensure_not_root() {
  if [[ "${EUID:-$(id -u)}" -eq 0 ]]; then
    echo "Erro: rode este script como usuario normal, nao como root." >&2
    exit 1
  fi
}

checkpoint_file() {
  printf '%s/checkpoints/%s.done\n' "$STATE_DIR" "$1"
}

has_checkpoint() {
  [[ -f "$(checkpoint_file "$1")" ]]
}

mark_checkpoint() {
  mkdir -p "$STATE_DIR/checkpoints"
  touch "$(checkpoint_file "$1")"
}

acquire_lock() {
  if [[ "$LOCK_HELD" == "1" ]]; then
    return
  fi

  mkdir -p "$STATE_DIR"
  if mkdir "$LOCK_DIR" 2>/dev/null; then
    printf '%s\n' "$$" >"$LOCK_DIR/pid"
    register_cleanup_path "$LOCK_DIR"
    export POSTINSTALL_LOCK_HELD=1
    return
  fi

  echo "Erro: ja existe outra execucao do script em andamento." >&2
  if [[ -f "$LOCK_DIR/pid" ]]; then
    echo "PID atual do lock: $(<"$LOCK_DIR/pid")" >&2
  fi
  exit 1
}

register_cleanup_path() {
  cleanup_paths+=("$1")
}

cleanup() {
  local path

  for path in "${cleanup_paths[@]}"; do
    [[ -n "$path" ]] || continue
    rm -rf "$path"
  done
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

get_host_name() {
  if command -v hostname >/dev/null 2>&1; then
    hostname
    return
  fi

  if command -v hostnamectl >/dev/null 2>&1; then
    hostnamectl hostname 2>/dev/null
    return
  fi

  if [[ -f /etc/hostname ]]; then
    cat /etc/hostname
    return
  fi

  uname -n
}

sanitize_label() {
  printf '%s' "$1" | tr -cs '[:alnum:].@_-' '-'
}

run_gh_auth_flow() {
  echo "Abrindo o navegador padrao para autenticacao do GitHub..."
  echo "O codigo de dispositivo sera copiado automaticamente para a area de transferencia."

  if [[ -t 0 ]]; then
    printf '\n' | gh "$@" --clipboard
    return
  fi

  gh "$@" --clipboard
}

append_package() {
  local package="$1"
  local existing

  for existing in "${packages[@]}"; do
    if [[ "$existing" == "$package" ]]; then
      return
    fi
  done

  packages+=("$package")
}

load_package_file() {
  local package_path="$1"
  local line

  if [[ ! -f "$package_path" ]]; then
    if [[ "$package_path" == "$EXTRA_PACKAGE_FILE" ]]; then
      echo "Pacotes extras nao encontrados em $package_path. Pulando."
    fi
    return 0
  fi

  while IFS= read -r line || [[ -n "$line" ]]; do
    [[ -n "$line" ]] || continue
    [[ "$line" =~ ^[[:space:]]*# ]] && continue
    append_package "$line"
  done <"$package_path"
}

ensure_arch() {
  if [[ ! -f /etc/arch-release ]]; then
    echo "Erro: este script foi feito para Arch Linux." >&2
    exit 1
  fi
}

load_packages() {
  [[ -f "$PACKAGE_FILE" ]] || {
    echo "Erro: lista de pacotes nao encontrada em $PACKAGE_FILE" >&2
    exit 1
  }

  packages=()
  load_package_file "$PACKAGE_FILE"
  load_package_file "$EXTRA_PACKAGE_FILE"
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

  if has_checkpoint "mirrors"; then
    echo "Mirrorlist ja atualizada anteriormente. Pulando."
    return
  fi

  if ! command -v reflector >/dev/null 2>&1; then
    echo "Instalando reflector..."
    retry sudo pacman -S --needed --noconfirm reflector
  fi

  echo "Atualizando mirrorlist com reflector..."
  backup_mirrorlist="$(mktemp)"
  temp_mirrorlist="$(mktemp)"
  register_cleanup_path "$backup_mirrorlist"
  register_cleanup_path "$temp_mirrorlist"

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
  mark_checkpoint "mirrors"
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
  local archive_file
  local status=0

  echo "Instalando yay..."
  mkdir -p "$REPOSITORIES_DIR"
  retry sudo pacman -S --needed --noconfirm base-devel
  require_command curl
  require_command tar

  archive_file="$(mktemp)"
  register_cleanup_path "$archive_file"

  echo "Baixando snapshot do yay..."
  if ! retry curl -fsSL "$YAY_SNAPSHOT_URL" -o "$archive_file"; then
    return 1
  fi

  rm -rf "$YAY_REPO_DIR"
  echo "Extraindo snapshot do yay em $YAY_REPO_DIR..."
  if ! tar -xzf "$archive_file" -C "$REPOSITORIES_DIR"; then
    return 1
  fi

  if [[ -d "$REPOSITORIES_DIR/yay" && "$REPOSITORIES_DIR/yay" != "$YAY_REPO_DIR" ]]; then
    mv "$REPOSITORIES_DIR/yay" "$YAY_REPO_DIR"
  fi

  if (( status == 0 )); then
    if retry build_yay "$YAY_REPO_DIR"; then
      aur_helper="yay"
    else
      status=$?
    fi
  fi

  return "$status"
}

ensure_aur_helper() {
  if detect_aur_helper; then
    echo "Usando helper AUR: $aur_helper"
    return
  fi

  echo "Nenhum helper AUR encontrado. Vou instalar o yay..."
  if ! install_yay; then
    echo "Erro: nao foi possivel preparar um helper AUR (yay)." >&2
    return 1
  fi
  echo "Usando helper AUR: $aur_helper"
}

install_packages_in_order() {
  local package
  local announced_aur_absence=0

  official_packages=()
  aur_packages=()

  for package in "${packages[@]}"; do
    case "$package" in
      codex)
        echo "Configurando Codex CLI..."
        setup_codex_cli
        continue
        ;;
    esac

    if pacman -Si "$package" >/dev/null 2>&1; then
      official_packages+=("$package")
      echo "Instalando via pacman: $package"
      if retry sudo pacman -S --needed --noconfirm "$package"; then
        continue
      fi

      official_failed+=("$package")
      continue
    fi

    if [[ "$announced_aur_absence" == "0" && ${#aur_packages[@]} == 0 ]]; then
      echo "Encontrado o primeiro pacote AUR na lista."
      announced_aur_absence=1
    fi

    aur_packages+=("$package")
    if ! ensure_aur_helper; then
      aur_failed+=("$package")
      continue
    fi

    echo "Instalando via AUR: $package"
    if retry "$aur_helper" -S --needed --noconfirm "$package"; then
      continue
    fi

    aur_failed+=("$package")
  done

  if ((${#aur_packages[@]} == 0)); then
    echo "Nenhum pacote AUR na lista. Pulando etapa do AUR."
  fi
}

print_summary() {
  local host_name
  local version_line

  host_name="$(get_host_name)"

  echo
  echo "Concluido."
  echo "Log: $LOG_FILE"
  echo "Resumo: $SUMMARY_FILE"
  echo "Hostname: $host_name"
  echo "Repo: $INSTALL_DIR"
  echo "Branch: $REPO_BRANCH"
  echo "Pacman: ${official_packages[*]:-nenhum}"
  echo "AUR: ${aur_packages[*]:-nenhum}"
  echo "Falhas pacman: ${official_failed[*]:-nenhuma}"
  echo "Falhas AUR: ${aur_failed[*]:-nenhuma}"
  echo "Verificados: ${verified_commands[*]:-nenhum}"
  echo "Ausentes: ${missing_commands[*]:-nenhum}"
  if ((${#version_info[@]} == 0)); then
    echo "Versoes: nenhuma"
  else
    echo "Versoes:"
    for version_line in "${version_info[@]}"; do
      echo "- $version_line"
    done
  fi

  mkdir -p "$(dirname "$SUMMARY_FILE")"
  cat >"$SUMMARY_FILE" <<EOF
Data: $(date '+%Y-%m-%d %H:%M:%S %z')
Log: $LOG_FILE
Hostname: $host_name
Repo: $INSTALL_DIR
Branch: $REPO_BRANCH
Pacman: ${official_packages[*]:-nenhum}
AUR: ${aur_packages[*]:-nenhum}
Falhas pacman: ${official_failed[*]:-nenhuma}
Falhas AUR: ${aur_failed[*]:-nenhuma}
Verificados: ${verified_commands[*]:-nenhum}
Ausentes: ${missing_commands[*]:-nenhum}
Versoes:
$(if ((${#version_info[@]} == 0)); then echo "- nenhuma"; else printf '%s\n' "${version_info[@]/#/- }"; fi)
Checkpoints:
- codex_cli: $(if has_checkpoint "codex_cli"; then echo concluido; else echo pendente; fi)
- github_ssh: $(if has_checkpoint "github_ssh"; then echo concluido; else echo pendente; fi)
- mirrors: $(if has_checkpoint "mirrors"; then echo concluido; else echo pendente; fi)
- zen_tabs: $(if has_checkpoint "zen_tabs"; then echo concluido; else echo pendente; fi)
EOF
}

open_zen_tabs() {
  if [[ "$OPEN_ZEN_TABS" != "1" ]]; then
    return
  fi

  if has_checkpoint "zen_tabs"; then
    echo "Abas do Zen ja abertas anteriormente. Pulando."
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
  mark_checkpoint "zen_tabs"
}

create_directories() {
  echo "Criando pastas base..."
  mkdir -p \
    "$HOME/Backups" \
    "$HOME/Codex" \
    "$HOME/Dots" \
    "$HOME/Pictures/Screenshots" \
    "$HOME/Pictures/Wallpapers" \
    "$HOME/Projects" \
    "$REPOSITORIES_DIR" \
    "$HOME/Videos"
}

setup_codex_cli() {
  local codex_path_line="export PATH=\"\$HOME/Codex/bin:\$PATH\""

  if has_checkpoint "codex_cli" && command -v codex >/dev/null 2>&1; then
    echo "Codex CLI ja configurado. Pulando."
    return
  fi

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
  mark_checkpoint "codex_cli"
}

ensure_ssh_key() {
  local ssh_dir
  local host_name
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
    host_name="$(sanitize_label "$(get_host_name)")"
    key_comment="${USER}@${host_name}"
  fi

  echo "Criando chave SSH em $SSH_KEY_PATH..."
  ssh-keygen -t ed25519 -C "$key_comment" -f "$SSH_KEY_PATH" -N ""
}

ensure_github_auth() {
  if gh auth status >/dev/null 2>&1; then
    echo "GitHub CLI ja autenticado."
    return
  fi

  echo "Autenticando no GitHub com gh..."
  run_gh_auth_flow auth login --web --git-protocol ssh
}

upload_ssh_key() {
  local current_key
  local current_key_id=""
  local existing_keys
  local key_id
  local key_ids

  current_key="$(<"${SSH_KEY_PATH}.pub")"
  if ! existing_keys="$(gh api user/keys --jq '.[] | [.id, .key] | @tsv' 2>/dev/null)"; then
    echo "Permissao admin:public_key ausente no gh. Vou renovar a autenticacao."
    if ! run_gh_auth_flow auth refresh -h github.com -s admin:public_key; then
      echo "Aviso: nao foi possivel renovar o escopo admin:public_key no gh."
      return 1
    fi

    if ! existing_keys="$(gh api user/keys --jq '.[] | [.id, .key] | @tsv' 2>/dev/null)"; then
      echo "Aviso: gh continua sem acesso para gerenciar chaves SSH no GitHub."
      return 1
    fi
  fi

  while IFS=$'\t' read -r key_id key_value; do
    [[ -n "$key_id" ]] || continue
    [[ -n "${key_value:-}" ]] || continue
    if [[ "$key_value" == "$current_key" ]]; then
      current_key_id="$key_id"
      break
    fi
  done <<<"$existing_keys"

  if [[ "$REPLACE_GITHUB_SSH_KEYS" != "1" && -n "$current_key_id" ]]; then
    echo "Chave SSH atual ja esta cadastrada no GitHub."
    return
  fi

  if [[ -z "$current_key_id" ]]; then
    echo "Enviando chave SSH para o GitHub..."
    current_key_id="$(retry gh api user/keys --method POST -f "title=obslove" -f "key=$current_key" --jq '.id')"
  else
    echo "Chave SSH atual ja existe no GitHub."
  fi

  if [[ "$REPLACE_GITHUB_SSH_KEYS" != "1" ]]; then
    return
  fi

  echo "Removendo chaves SSH antigas do GitHub..."
  key_ids="$(gh api user/keys --jq '.[].id' 2>/dev/null || true)"
  while IFS= read -r key_id; do
    [[ -n "$key_id" ]] || continue
    [[ "$key_id" =~ ^[0-9]+$ ]] || continue
    [[ "$key_id" == "$current_key_id" ]] && continue
    retry gh api --method DELETE "user/keys/$key_id"
  done <<<"$key_ids"
}

repo_is_dirty() {
  ! git -C "$INSTALL_DIR" diff --quiet --no-ext-diff || \
    ! git -C "$INSTALL_DIR" diff --cached --quiet --no-ext-diff || \
    [[ -n "$(git -C "$INSTALL_DIR" status --porcelain --untracked-files=normal)" ]]
}

sync_repo() {
  local fetched_origin=0

  mkdir -p "$(dirname "$INSTALL_DIR")"

  if [[ -d "$INSTALL_DIR/.git" ]]; then
    echo "Atualizando repositorio em $INSTALL_DIR..."
    git -C "$INSTALL_DIR" remote set-url origin "$REPO_HTTPS_URL"
    if repo_is_dirty; then
      echo "Aviso: repositorio local tem mudancas. Pulando atualizacao automatica."
      return
    fi

    if retry git -C "$INSTALL_DIR" fetch origin; then
      fetched_origin=1
    else
      echo "Aviso: falha ao buscar atualizacoes de origin. Vou tentar usar a copia local."
    fi

    if git -C "$INSTALL_DIR" show-ref --verify --quiet "refs/heads/$REPO_BRANCH"; then
      git -C "$INSTALL_DIR" checkout "$REPO_BRANCH"
    elif git -C "$INSTALL_DIR" show-ref --verify --quiet "refs/remotes/origin/$REPO_BRANCH"; then
      git -C "$INSTALL_DIR" checkout -b "$REPO_BRANCH" "origin/$REPO_BRANCH"
    elif [[ "$fetched_origin" == "0" ]]; then
      echo "Erro: nao foi possivel atualizar origin e a branch '$REPO_BRANCH' nao existe localmente." >&2
      echo "Verifique acesso ao GitHub ou rode uma branch ja presente no clone local." >&2
      exit 1
    else
      echo "Erro: branch '$REPO_BRANCH' nao encontrada no repositorio local nem em origin." >&2
      exit 1
    fi

    if [[ "$fetched_origin" == "0" ]]; then
      echo "Aviso: pulando 'git pull' porque o fetch de origin falhou. Continuando com a branch local."
      return
    fi

    if ! retry git -C "$INSTALL_DIR" pull --ff-only origin "$REPO_BRANCH"; then
      echo "Aviso: falha ao atualizar '$REPO_BRANCH' via 'git pull --ff-only'. Continuando com a copia atual."
    fi
  else
    if [[ -e "$INSTALL_DIR" ]]; then
      echo "Erro: $INSTALL_DIR ja existe e nao e um repositorio git." >&2
      exit 1
    fi

    echo "Clonando repositorio em $INSTALL_DIR..."
    if ! retry git clone --branch "$REPO_BRANCH" --single-branch "$REPO_HTTPS_URL" "$INSTALL_DIR"; then
      echo "Erro: falha ao clonar '$REPO_BRANCH' de $REPO_HTTPS_URL." >&2
      echo "Verifique acesso ao GitHub e se a branch existe no remoto." >&2
      exit 1
    fi
  fi
}

run_bootstrap() {
  retry sudo pacman -Syu --needed --noconfirm git

  require_command git
  sync_repo

  env \
    BOOTSTRAP_BRANCH="$REPO_BRANCH" \
    BOOTSTRAP_DIR="$INSTALL_DIR" \
    POSTINSTALL_LOG_FILE="$LOG_FILE" \
    POSTINSTALL_LOG_INITIALIZED=1 \
    POSTINSTALL_LOCK_HELD=1 \
    POSTINSTALL_SYSTEM_UPDATED=1 \
    OPEN_ZEN_TABS="$OPEN_ZEN_TABS" \
    REPLACE_GITHUB_SSH_KEYS="$REPLACE_GITHUB_SSH_KEYS" \
    RETRY_ATTEMPTS="$RETRY_ATTEMPTS" \
    RETRY_DELAY_SECONDS="$RETRY_DELAY_SECONDS" \
    bash "$INSTALL_DIR/install.sh" "$REPO_BRANCH"
  exit $?
}

setup_github_ssh() {
  if has_checkpoint "github_ssh" && command -v gh >/dev/null 2>&1 && gh auth status >/dev/null 2>&1 && [[ -f "${SSH_KEY_PATH}.pub" ]]; then
    echo "GitHub SSH ja configurado. Pulando."
    return
  fi

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
  mark_checkpoint "github_ssh"
}

verify_command() {
  local label="$1"
  local command_name="$2"

  if command -v "$command_name" >/dev/null 2>&1; then
    verified_commands+=("$label")
    return
  fi

  missing_commands+=("$label")
}

collect_version() {
  local label="$1"
  shift
  local output

  if ! command -v "$1" >/dev/null 2>&1; then
    return
  fi

  output="$("$@" 2>/dev/null | sed -n '1p' || true)"
  if [[ -z "$output" ]]; then
    version_info+=("$label: versao indisponivel")
    return 0
  fi
  version_info+=("$label: $output")
}

verify_installation() {
  verified_commands=()
  missing_commands=()
  version_info=()

  verify_command "code" "code"
  verify_command "discord" "discord"
  verify_command "gh" "gh"
  verify_command "google-chrome-stable" "google-chrome-stable"
  verify_command "node" "node"
  verify_command "npm" "npm"
  verify_command "codex" "codex"
  verify_command "ssh-keygen" "ssh-keygen"
  verify_command "steam" "steam"
  verify_command "zen-browser" "zen-browser"

  collect_version "node" node --version
  collect_version "npm" npm --version
  collect_version "gh" gh --version
  collect_version "codex" codex --version
  collect_version "zen-browser" zen-browser --version
  collect_version "google-chrome-stable" google-chrome-stable --version
}

run_install() {
  load_packages
  create_directories
  ensure_multilib
  optimize_mirrors

  if [[ "$SYSTEM_UPDATED" == "1" ]]; then
    echo "Sistema ja atualizado no bootstrap. Pulando nova atualizacao completa."
  else
    echo "Atualizando o sistema..."
    retry sudo pacman -Syu --noconfirm
  fi

  install_packages_in_order

  if ((${#official_failed[@]} > 0 || ${#aur_failed[@]} > 0)); then
    print_summary
    exit 1
  fi
  setup_github_ssh
  verify_installation
  open_zen_tabs
  print_summary
}

main() {
  trap cleanup EXIT
  ensure_not_root
  acquire_lock
  init_logging
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
