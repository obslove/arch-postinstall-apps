#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
PACKAGE_FILE="$SCRIPT_DIR/config/packages.txt"
EXTRA_PACKAGE_FILE="$SCRIPT_DIR/config/packages-extra.txt"
BASHRC_FILE="$HOME/.bashrc"
ZSHRC_FILE="$HOME/.zshrc"
FISH_CONFIG_FILE="$HOME/.config/fish/config.fish"
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
REPLACE_GITHUB_SSH_KEYS="${REPLACE_GITHUB_SSH_KEYS:-1}"
RETRY_ATTEMPTS="${RETRY_ATTEMPTS:-3}"
RETRY_DELAY_SECONDS="${RETRY_DELAY_SECONDS:-5}"
STEP_OUTPUT_ONLY="${STEP_OUTPUT_ONLY:-1}"
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
temp_clipboard_package=""
official_repo_index_file=""

ensure_not_root() {
  if [[ "${EUID:-$(id -u)}" -eq 0 ]]; then
    echo "Erro: execute este script como usuário comum, e não como root." >&2
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
  local existing_pid=""

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

  if [[ -f "$LOCK_DIR/pid" ]]; then
    existing_pid="$(<"$LOCK_DIR/pid")"
  fi

  if [[ -z "$existing_pid" ]] || ! kill -0 "$existing_pid" 2>/dev/null; then
    echo "Aviso: foi detectado um lock órfão. Limpando a execução anterior."
    rm -rf "$LOCK_DIR"
    if mkdir "$LOCK_DIR" 2>/dev/null; then
      printf '%s\n' "$$" >"$LOCK_DIR/pid"
      register_cleanup_path "$LOCK_DIR"
      export POSTINSTALL_LOCK_HELD=1
      return
    fi
  fi

  echo "Erro: já existe outra execução do script em andamento." >&2
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
}

announce_step() {
  echo
  echo "$1"
}

announce_detail() {
  if [[ "$STEP_OUTPUT_ONLY" == "1" ]]; then
    printf '%s\n' "$1" >>"$LOG_FILE"
    return
  fi

  echo "$1"
}

run_log_only() {
  "$@" >>"$LOG_FILE" 2>&1
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

retry_log_only() {
  local attempt=1
  local exit_code=0

  while true; do
    if run_log_only "$@"; then
      return 0
    else
      exit_code=$?
    fi

    if (( attempt >= RETRY_ATTEMPTS )); then
      return "$exit_code"
    fi

    echo "Tentativa $attempt/$RETRY_ATTEMPTS falhou. Repetindo em ${RETRY_DELAY_SECONDS}s. Veja o log para detalhes."
    sleep "$RETRY_DELAY_SECONDS"
    attempt=$((attempt + 1))
  done
}

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Erro: comando obrigatório não encontrado: $1" >&2
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

build_ssh_key_title() {
  printf 'vampire love\n'
}

is_wayland_session() {
  [[ "${XDG_SESSION_TYPE:-}" == "wayland" || -n "${WAYLAND_DISPLAY:-}" ]]
}

is_hyprland_session() {
  [[ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]] || \
    [[ "${XDG_CURRENT_DESKTOP:-}" == *Hyprland* ]] || \
    [[ "${DESKTOP_SESSION:-}" == "hyprland" ]]
}

has_clipboard_utility() {
  command -v wl-copy >/dev/null 2>&1 || \
    command -v termux-clipboard-set >/dev/null 2>&1
}

has_session_clipboard_utility() {
  if is_wayland_session; then
    command -v wl-copy >/dev/null 2>&1 && return 0
    command -v termux-clipboard-set >/dev/null 2>&1 && return 0
    return 1
  fi

  has_clipboard_utility
}

ensure_temp_clipboard_utility() {
  local clipboard_package=""

  if has_session_clipboard_utility; then
    return 0
  fi

  if is_wayland_session; then
    clipboard_package="wl-clipboard"
  else
    return 1
  fi

  if pacman -Q "$clipboard_package" >/dev/null 2>&1; then
    return 0
  fi

  announce_detail "Instalando $clipboard_package temporariamente para copiar o código do GitHub..."
  if ! retry_log_only sudo pacman -S --needed --noconfirm "$clipboard_package"; then
    echo "Aviso: não foi possível instalar $clipboard_package. Continuando sem cópia automática."
    return 1
  fi

  temp_clipboard_package="$clipboard_package"
  return 0
}

cleanup_temp_clipboard_utility() {
  if [[ -z "$temp_clipboard_package" ]]; then
    return 0
  fi

  announce_detail "Removendo $temp_clipboard_package instalado temporariamente..."
  if ! retry_log_only sudo pacman -Rns --noconfirm "$temp_clipboard_package"; then
    echo "Aviso: não foi possível remover $temp_clipboard_package automaticamente."
    return 1
  fi

  temp_clipboard_package=""
}

ensure_hyprland_desktop_integration() {
  if ! is_hyprland_session; then
    return 0
  fi

  announce_detail "Garantindo integração desktop para Hyprland..."
  if ! retry_log_only sudo pacman -S --needed --noconfirm \
    pipewire \
    wireplumber \
    xdg-utils \
    xdg-desktop-portal \
    xdg-desktop-portal-gtk \
    xdg-desktop-portal-hyprland; then
    echo "Aviso: não foi possível instalar a integração desktop do Hyprland."
    return 1
  fi
}

run_gh_auth_flow() {
  local clipboard_args=()

  echo "Iniciando a autenticação do GitHub..."
  if ensure_temp_clipboard_utility; then
    clipboard_args+=(--clipboard)
    echo "O código de dispositivo será copiado automaticamente para a área de transferência."
  else
    echo "Área de transferência indisponível. Copie o código manualmente no terminal."
  fi

  if [[ -t 0 ]]; then
    printf '\n' | gh "$@" "${clipboard_args[@]}"
    return
  fi

  gh "$@" "${clipboard_args[@]}"
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
      announce_detail "Pacotes extras não encontrados em $package_path. Etapa ignorada."
    fi
    return 0
  fi

  while IFS= read -r line || [[ -n "$line" ]]; do
    line="${line#"${line%%[![:space:]]*}"}"
    line="${line%"${line##*[![:space:]]}"}"
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
    echo "Erro: lista de pacotes não encontrada em $PACKAGE_FILE" >&2
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
    announce_detail "O repositório multilib já está habilitado."
    return
  fi

  announce_detail "Habilitando o repositório multilib..."
  sudo cp /etc/pacman.conf "/etc/pacman.conf.bak.$(date +%Y%m%d%H%M%S)"
  sudo sed -i \
    '/^[[:space:]]*#\[multilib\][[:space:]]*$/,/^[[:space:]]*#Include = \/etc\/pacman.d\/mirrorlist[[:space:]]*$/ s/^[[:space:]]*#//' \
    /etc/pacman.conf

  if ! multilib_enabled; then
    echo "Erro: não foi possível habilitar multilib automaticamente." >&2
    exit 1
  fi

  run_log_only sudo pacman -Syy --noconfirm
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

refresh_official_repo_index() {
  if [[ -n "$official_repo_index_file" && -f "$official_repo_index_file" ]]; then
    return 0
  fi

  official_repo_index_file="$(mktemp)"
  register_cleanup_path "$official_repo_index_file"

  if ! pacman -Slq | sort -u >"$official_repo_index_file"; then
    echo "Erro: não foi possível carregar a lista de pacotes oficiais do pacman." >&2
    return 1
  fi
}

package_exists_in_official_repos() {
  local package="$1"

  refresh_official_repo_index
  grep -qxF "$package" "$official_repo_index_file"
}

install_yay() {
  local archive_file
  local status=0

  announce_step "Preparando helper AUR..."
  mkdir -p "$REPOSITORIES_DIR"
  retry_log_only sudo pacman -S --needed --noconfirm base-devel
  require_command curl
  require_command tar

  archive_file="$(mktemp)"
  register_cleanup_path "$archive_file"

  announce_detail "Baixando snapshot do yay..."
  if ! retry curl -fsSL "$YAY_SNAPSHOT_URL" -o "$archive_file"; then
    return 1
  fi

  rm -rf "$YAY_REPO_DIR"
  announce_detail "Extraindo snapshot do yay em $YAY_REPO_DIR..."
  if ! tar -xzf "$archive_file" -C "$REPOSITORIES_DIR"; then
    return 1
  fi

  if [[ -d "$REPOSITORIES_DIR/yay" && "$REPOSITORIES_DIR/yay" != "$YAY_REPO_DIR" ]]; then
    mv "$REPOSITORIES_DIR/yay" "$YAY_REPO_DIR"
  fi

  if (( status == 0 )); then
    if retry_log_only build_yay "$YAY_REPO_DIR"; then
      aur_helper="yay"
    else
      status=$?
    fi
  fi

  return "$status"
}

ensure_aur_helper() {
  if detect_aur_helper; then
    announce_detail "Usando helper AUR: $aur_helper"
    return
  fi

  announce_detail "Nenhum helper AUR foi encontrado. O script instalará o yay..."
  if ! install_yay; then
    echo "Erro: não foi possível preparar um helper AUR (yay)." >&2
    return 1
  fi
  announce_detail "Usando helper AUR: $aur_helper"
}

github_ssh_ready() {
  [[ -f "${SSH_KEY_PATH}.pub" ]] || return 1
  command -v gh >/dev/null 2>&1 || return 1
  gh auth status >/dev/null 2>&1 || return 1
  has_checkpoint "github_ssh" || return 1
  github_has_current_ssh_key
}

github_has_current_ssh_key() {
  local current_key
  local existing_keys

  [[ -f "${SSH_KEY_PATH}.pub" ]] || return 1
  current_key="$(<"${SSH_KEY_PATH}.pub")"
  existing_keys="$(gh api user/keys --jq '.[].key' 2>/dev/null || true)"
  [[ -n "$existing_keys" ]] || return 1
  grep -qxF "$current_key" <<<"$existing_keys"
}

desired_repo_origin_url() {
  if github_ssh_ready; then
    printf '%s\n' "$REPO_SSH_URL"
    return
  fi

  printf '%s\n' "$REPO_HTTPS_URL"
}

ensure_repo_origin_remote() {
  local repo_dir="$1"
  local current_origin_url=""
  local desired_origin_url

  desired_origin_url="$(desired_repo_origin_url)"
  current_origin_url="$(git -C "$repo_dir" remote get-url origin 2>/dev/null || true)"

  if [[ -z "$current_origin_url" ]]; then
    git -C "$repo_dir" remote add origin "$desired_origin_url"
    return
  fi

  if [[ "$current_origin_url" != "$REPO_HTTPS_URL" && "$current_origin_url" != "$REPO_SSH_URL" ]]; then
    announce_detail "Foi detectado um remoto origin personalizado em $repo_dir. A configuração atual será mantida."
    return
  fi

  if [[ "$current_origin_url" != "$desired_origin_url" ]]; then
    git -C "$repo_dir" remote set-url origin "$desired_origin_url"
  fi
}

get_repo_branch() {
  local repo_dir="$1"
  local branch_name=""

  if ! git -C "$repo_dir" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    return 1
  fi

  branch_name="$(git -C "$repo_dir" symbolic-ref --quiet --short HEAD 2>/dev/null || true)"
  if [[ -n "$branch_name" ]]; then
    printf '%s\n' "$branch_name"
    return 0
  fi

  branch_name="$(git -C "$repo_dir" rev-parse --short HEAD 2>/dev/null || true)"
  [[ -n "$branch_name" ]] || return 1
  printf 'detached@%s\n' "$branch_name"
}

install_packages_in_order() {
  local package
  local announced_aur_absence=0
  local shown_pacman_step=0
  local shown_aur_step=0

  refresh_official_repo_index

  official_packages=()
  aur_packages=()

  for package in "${packages[@]}"; do
    case "$package" in
      codex)
      announce_step "Configurando Codex CLI..."
        setup_codex_cli
        continue
        ;;
    esac

    if package_exists_in_official_repos "$package"; then
      official_packages+=("$package")
      if [[ "$shown_pacman_step" == "0" ]]; then
        announce_step "Instalando apps oficiais..."
        shown_pacman_step=1
      fi
      announce_detail "Instalando via pacman: $package"
      if retry_log_only sudo pacman -S --needed --noconfirm "$package"; then
        continue
      fi

      official_failed+=("$package")
      continue
    fi

    if [[ "$announced_aur_absence" == "0" && ${#aur_packages[@]} == 0 ]]; then
      announce_detail "O primeiro pacote AUR foi encontrado na lista."
      announced_aur_absence=1
    fi

    aur_packages+=("$package")
    if ! ensure_aur_helper; then
      aur_failed+=("$package")
      continue
    fi

    if [[ "$shown_aur_step" == "0" ]]; then
      announce_step "Instalando apps AUR..."
      shown_aur_step=1
    fi
    announce_detail "Instalando via AUR: $package"
    if retry_log_only "$aur_helper" -S --needed --noconfirm "$package"; then
      continue
    fi

    aur_failed+=("$package")
  done

  if ((${#aur_packages[@]} == 0)); then
    announce_detail "Nenhum pacote AUR foi encontrado na lista. A etapa do AUR será ignorada."
  fi
}

print_summary() {
  local host_name
  local actual_branch
  local repo_path
  local requested_branch_note=""
  local version_line

  host_name="$(get_host_name)"
  actual_branch="$(get_repo_branch "$SCRIPT_DIR" 2>/dev/null || printf '%s\n' "$REPO_BRANCH")"
  repo_path="$SCRIPT_DIR"
  if [[ "$actual_branch" != "$REPO_BRANCH" ]]; then
    requested_branch_note="$REPO_BRANCH"
  fi

  if [[ "$STEP_OUTPUT_ONLY" == "1" ]]; then
    echo
    echo "Concluído."
    echo "Log: $LOG_FILE"
    echo "Resumo: $SUMMARY_FILE"
  else
    echo
    echo "Concluído."
    echo "Log: $LOG_FILE"
    echo "Resumo: $SUMMARY_FILE"
    echo "Hostname: $host_name"
    echo "Repositório: $repo_path"
    echo "Branch: $actual_branch"
    if [[ -n "$requested_branch_note" ]]; then
      echo "Branch solicitada: $requested_branch_note"
    fi
    echo "Pacman: ${official_packages[*]:-nenhum}"
    echo "AUR: ${aur_packages[*]:-nenhum}"
    echo "Falhas pacman: ${official_failed[*]:-nenhuma}"
    echo "Falhas AUR: ${aur_failed[*]:-nenhuma}"
    echo "Verificados: ${verified_commands[*]:-nenhum}"
    echo "Ausentes: ${missing_commands[*]:-nenhum}"
    if ((${#version_info[@]} == 0)); then
      echo "Versões: nenhuma"
    else
      echo "Versões:"
      for version_line in "${version_info[@]}"; do
        echo "- $version_line"
      done
    fi
  fi

  mkdir -p "$(dirname "$SUMMARY_FILE")"
  cat >"$SUMMARY_FILE" <<EOF
Data: $(date '+%Y-%m-%d %H:%M:%S %z')
Log: $LOG_FILE
Hostname: $host_name
Repositório: $repo_path
Branch: $actual_branch
$(if [[ -n "$requested_branch_note" ]]; then printf 'Branch solicitada: %s\n' "$requested_branch_note"; fi)
Pacman: ${official_packages[*]:-nenhum}
AUR: ${aur_packages[*]:-nenhum}
Falhas pacman: ${official_failed[*]:-nenhuma}
Falhas AUR: ${aur_failed[*]:-nenhuma}
Verificados: ${verified_commands[*]:-nenhum}
Ausentes: ${missing_commands[*]:-nenhum}
Versões:
$(if ((${#version_info[@]} == 0)); then echo "- nenhuma"; else printf '%s\n' "${version_info[@]/#/- }"; fi)
Checkpoints:
- codex_cli: $(if has_checkpoint "codex_cli"; then echo concluido; else echo pendente; fi)
- github_ssh: $(if has_checkpoint "github_ssh"; then echo concluido; else echo pendente; fi)
EOF

  if [[ "$SCRIPT_DIR" != "$INSTALL_DIR" ]]; then
    printf 'Clone gerenciado: %s\n' "$INSTALL_DIR" >>"$SUMMARY_FILE"
  fi
}

create_directories() {
  announce_step "Criando diretórios..."
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

current_public_ssh_key() {
  [[ -f "${SSH_KEY_PATH}.pub" ]] || return 1
  awk 'NR == 1 { print $1, $2 }' "${SSH_KEY_PATH}.pub"
}

find_current_github_ssh_key() {
  local current_key

  current_key="$(current_public_ssh_key)" || return 1
  gh api user/keys --jq ".[] | select(.key == \"$current_key\") | [.id, .title] | @tsv"
}

github_has_expected_ssh_key_title() {
  local key_data
  local current_key_title=""

  key_data="$(find_current_github_ssh_key 2>/dev/null || true)"
  [[ -n "$key_data" ]] || return 1
  IFS=$'\t' read -r _ current_key_title <<<"$key_data"
  [[ "$current_key_title" == "$(build_ssh_key_title)" ]]
}

setup_codex_cli() {
  local codex_path_line="export PATH=\"\$HOME/Codex/bin:\$PATH\""
  local fish_codex_path_marker="if not contains \"\$HOME/Codex/bin\" \$PATH"
  local fish_codex_path_block="if not contains \"\$HOME/Codex/bin\" \$PATH
    set -gx PATH \"\$HOME/Codex/bin\" \$PATH
end"

  if has_checkpoint "codex_cli" && command -v codex >/dev/null 2>&1; then
    announce_detail "O Codex CLI já está configurado. Etapa ignorada."
    return
  fi

  require_command npm

  announce_detail "Configurando o prefixo do npm em $HOME/Codex..."
  run_log_only npm config set prefix "$HOME/Codex"

  if [[ ! -f "$BASHRC_FILE" ]]; then
    touch "$BASHRC_FILE"
  fi

  if ! grep -qxF "$codex_path_line" "$BASHRC_FILE"; then
    printf '\n%s\n' "$codex_path_line" >>"$BASHRC_FILE"
  fi

  if [[ ! -f "$ZSHRC_FILE" ]]; then
    touch "$ZSHRC_FILE"
  fi

  if ! grep -qxF "$codex_path_line" "$ZSHRC_FILE"; then
    printf '\n%s\n' "$codex_path_line" >>"$ZSHRC_FILE"
  fi

  mkdir -p "$(dirname "$FISH_CONFIG_FILE")"
  if [[ ! -f "$FISH_CONFIG_FILE" ]]; then
    touch "$FISH_CONFIG_FILE"
  fi

  if ! grep -qxF "$fish_codex_path_marker" "$FISH_CONFIG_FILE"; then
    printf '\n%s\n' "$fish_codex_path_block" >>"$FISH_CONFIG_FILE"
  fi

  export PATH="$HOME/Codex/bin:$PATH"

  announce_detail "Instalando Codex CLI em $HOME/Codex..."
  retry_log_only npm install -g @openai/codex
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
    announce_detail "A chave SSH já existe em $SSH_KEY_PATH."
    return
  fi

  key_comment="$(git config --global user.email 2>/dev/null || true)"
  if [[ -z "$key_comment" ]]; then
    host_name="$(sanitize_label "$(get_host_name)")"
    key_comment="${USER}@${host_name}"
  fi

  announce_detail "Criando chave SSH em $SSH_KEY_PATH..."
  ssh-keygen -t ed25519 -C "$key_comment" -f "$SSH_KEY_PATH" -N ""
}

ensure_github_auth() {
  if gh auth status >/dev/null 2>&1; then
    announce_detail "GitHub CLI já autenticado."
    return
  fi

  echo "Autenticando no GitHub com gh..."
  run_gh_auth_flow auth login --web --git-protocol ssh
}

upload_ssh_key() {
  local current_key
  local current_key_id=""
  local current_key_title=""
  local existing_keys
  local key_id
  local key_title_from_api
  local key_value
  local key_ids
  local key_title

  current_key="$(current_public_ssh_key)"
  key_title="$(build_ssh_key_title)"
  if ! existing_keys="$(gh api user/keys --jq '.[] | [.id, .title, .key] | @tsv' 2>/dev/null)"; then
    announce_detail "A permissão admin:public_key não está disponível no gh. A autenticação será renovada."
    if ! run_gh_auth_flow auth refresh -h github.com -s admin:public_key; then
      echo "Aviso: não foi possível renovar o escopo admin:public_key no gh."
      return 1
    fi

    if ! existing_keys="$(gh api user/keys --jq '.[] | [.id, .title, .key] | @tsv' 2>/dev/null)"; then
      echo "Aviso: o gh continua sem acesso para gerenciar chaves SSH no GitHub."
      return 1
    fi
  fi

  while IFS=$'\t' read -r key_id key_title_from_api key_value; do
    [[ -n "$key_id" ]] || continue
    [[ -n "${key_value:-}" ]] || continue
    if [[ "$key_value" == "$current_key" ]]; then
      current_key_id="$key_id"
      current_key_title="$key_title_from_api"
      break
    fi
  done <<<"$existing_keys"

  if [[ -n "$current_key_id" && "$current_key_title" != "$key_title" ]]; then
    announce_detail "A chave SSH atual já existe no GitHub com outro título. Recriando com o nome correto..."
    retry gh api --method DELETE "user/keys/$current_key_id"
    current_key_id=""
  fi

  if [[ "$REPLACE_GITHUB_SSH_KEYS" != "1" && -n "$current_key_id" ]]; then
    announce_detail "A chave SSH atual já está cadastrada no GitHub."
    return
  fi

  if [[ -z "$current_key_id" ]]; then
    announce_detail "Enviando a chave SSH ao GitHub..."
    current_key_id="$(retry gh api user/keys --method POST -f "title=$key_title" -f "key=$current_key" --jq '.id')"
  else
    announce_detail "A chave SSH atual já existe no GitHub."
  fi

  if [[ "$REPLACE_GITHUB_SSH_KEYS" != "1" ]]; then
    return
  fi

  announce_detail "Removendo chaves SSH antigas do GitHub..."
  key_ids="$(gh api user/keys --jq '.[].id' 2>/dev/null || true)"
  while IFS= read -r key_id; do
    [[ -n "$key_id" ]] || continue
    [[ "$key_id" =~ ^[0-9]+$ ]] || continue
    [[ "$key_id" == "$current_key_id" ]] && continue
    retry gh api --method DELETE "user/keys/$key_id"
  done <<<"$key_ids"

  if ! github_has_expected_ssh_key_title; then
    echo "Aviso: a chave SSH foi enviada, mas o título esperado no GitHub não pôde ser confirmado."
    return 1
  fi
}

repo_is_dirty() {
  ! git -C "$INSTALL_DIR" diff --quiet --no-ext-diff || \
    ! git -C "$INSTALL_DIR" diff --cached --quiet --no-ext-diff || \
    [[ -n "$(git -C "$INSTALL_DIR" status --porcelain --untracked-files=normal)" ]]
}

sync_repo() {
  local current_branch=""
  local fetched_origin=0

  mkdir -p "$(dirname "$INSTALL_DIR")"

  if [[ -d "$INSTALL_DIR/.git" ]]; then
    announce_step "Atualizando repositório..."
    if repo_is_dirty; then
      current_branch="$(get_repo_branch "$INSTALL_DIR" 2>/dev/null || true)"
      if [[ -n "$current_branch" && "$current_branch" != "$REPO_BRANCH" ]]; then
        echo "Erro: o clone gerenciado está com mudanças locais na branch '$current_branch'." >&2
        echo "Não dá para executar com segurança a branch solicitada '$REPO_BRANCH' sem limpar ou mover essas mudanças." >&2
        exit 1
      fi

      echo "Aviso: o repositório local tem alterações. A atualização automática será ignorada."
      return
    fi

    ensure_repo_origin_remote "$INSTALL_DIR"

    if retry_log_only git -C "$INSTALL_DIR" fetch origin; then
      fetched_origin=1
    else
      echo "Aviso: falha ao buscar atualizações de origin. O script tentará usar a cópia local."
    fi

    if git -C "$INSTALL_DIR" show-ref --verify --quiet "refs/heads/$REPO_BRANCH"; then
      git -C "$INSTALL_DIR" checkout "$REPO_BRANCH"
    elif git -C "$INSTALL_DIR" show-ref --verify --quiet "refs/remotes/origin/$REPO_BRANCH"; then
      git -C "$INSTALL_DIR" checkout -b "$REPO_BRANCH" "origin/$REPO_BRANCH"
    elif [[ "$fetched_origin" == "0" ]]; then
      echo "Erro: não foi possível atualizar origin e a branch '$REPO_BRANCH' não existe localmente." >&2
      echo "Verifique acesso ao GitHub ou rode uma branch já presente no clone local." >&2
      exit 1
    else
      echo "Erro: branch '$REPO_BRANCH' não encontrada no repositório local nem em origin." >&2
      exit 1
    fi

    if [[ "$fetched_origin" == "0" ]]; then
      echo "Aviso: o 'git pull' será ignorado porque o fetch de origin falhou. O script continuará com a branch local."
      return
    fi

    if ! retry_log_only git -C "$INSTALL_DIR" pull --ff-only origin "$REPO_BRANCH"; then
      echo "Aviso: falha ao atualizar '$REPO_BRANCH' com 'git pull --ff-only'. O script continuará com a cópia atual."
    fi
  else
    if [[ -e "$INSTALL_DIR" ]]; then
      echo "Erro: $INSTALL_DIR já existe e não é um repositório git." >&2
      exit 1
    fi

    announce_step "Clonando repositório..."
    if ! retry_log_only git clone --branch "$REPO_BRANCH" --single-branch "$REPO_HTTPS_URL" "$INSTALL_DIR"; then
      echo "Erro: falha ao clonar '$REPO_BRANCH' de $REPO_HTTPS_URL." >&2
      echo "Verifique acesso ao GitHub e se a branch existe no remoto." >&2
      exit 1
    fi
  fi
}

run_bootstrap() {
  announce_step "Instalando dependências iniciais..."
  retry_log_only sudo pacman -Syu --needed --noconfirm git

  require_command git
  sync_repo

  env \
    BOOTSTRAP_BRANCH="$REPO_BRANCH" \
    BOOTSTRAP_DIR="$INSTALL_DIR" \
    POSTINSTALL_LOG_FILE="$LOG_FILE" \
    POSTINSTALL_LOG_INITIALIZED=1 \
    POSTINSTALL_LOCK_HELD=1 \
    POSTINSTALL_SYSTEM_UPDATED=1 \
    REPLACE_GITHUB_SSH_KEYS="$REPLACE_GITHUB_SSH_KEYS" \
    RETRY_ATTEMPTS="$RETRY_ATTEMPTS" \
    RETRY_DELAY_SECONDS="$RETRY_DELAY_SECONDS" \
    bash "$INSTALL_DIR/install.sh" "$REPO_BRANCH"
  exit $?
}

setup_github_ssh() {
  if has_checkpoint "github_ssh" && command -v gh >/dev/null 2>&1 && gh auth status >/dev/null 2>&1 && github_has_expected_ssh_key_title; then
    ensure_repo_origin_remote "$SCRIPT_DIR"
    announce_detail "O GitHub SSH já está configurado. Etapa ignorada."
    return
  fi

  announce_step "Configurando GitHub SSH..."
  if ! retry_log_only sudo pacman -S --needed --noconfirm github-cli openssh; then
    echo "Aviso: não foi possível instalar github-cli/openssh. A configuração do GitHub será ignorada."
    return
  fi

  if ! command -v gh >/dev/null 2>&1 || ! command -v ssh-keygen >/dev/null 2>&1; then
    echo "Aviso: github-cli ou ssh-keygen está indisponível. A configuração do GitHub será ignorada."
    return
  fi

  ensure_ssh_key
  if ! ensure_github_auth; then
    cleanup_temp_clipboard_utility || true
    echo "Aviso: a autenticação do GitHub não foi concluída. O envio da chave SSH será ignorado."
    return
  fi

  if ! upload_ssh_key; then
    cleanup_temp_clipboard_utility || true
    echo "Aviso: não foi possível enviar a chave SSH para o GitHub."
    return
  fi

  cleanup_temp_clipboard_utility || true
  mark_checkpoint "github_ssh"
  ensure_repo_origin_remote "$SCRIPT_DIR"
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

verify_package() {
  local label="$1"
  local package_name="$2"

  if pacman -Q "$package_name" >/dev/null 2>&1; then
    verified_commands+=("$label")
    return
  fi

  missing_commands+=("$label")
}

user_service_exists() {
  local service_name="$1"

  systemctl --user cat "$service_name" >/dev/null 2>&1
}

verify_user_service() {
  local label="$1"
  local service_name="$2"

  if ! command -v systemctl >/dev/null 2>&1; then
    missing_commands+=("$label")
    return
  fi

  if ! user_service_exists "$service_name"; then
    missing_commands+=("$label")
    return
  fi

  if systemctl --user --quiet is-active "$service_name"; then
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
    version_info+=("$label: versão indisponível")
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

  if command -v xdg-open >/dev/null 2>&1; then
    verified_commands+=("xdg-open")
  elif command -v gio >/dev/null 2>&1; then
    verified_commands+=("gio-open")
  else
    missing_commands+=("xdg-open")
  fi

  if is_wayland_session; then
    if command -v wl-copy >/dev/null 2>&1 && command -v wl-paste >/dev/null 2>&1; then
      verified_commands+=("wayland-clipboard")
    else
      missing_commands+=("wayland-clipboard")
    fi
  fi

  if is_hyprland_session; then
    verify_command "pipewire" "pipewire"
    verify_command "wireplumber" "wireplumber"
    verify_package "xdg-desktop-portal" "xdg-desktop-portal"
    verify_package "xdg-desktop-portal-gtk" "xdg-desktop-portal-gtk"
    verify_package "xdg-desktop-portal-hyprland" "xdg-desktop-portal-hyprland"
  fi

  if is_wayland_session; then
    verify_user_service "pipewire.service" "pipewire.service"
    verify_user_service "wireplumber.service" "wireplumber.service"
    verify_user_service "xdg-desktop-portal.service" "xdg-desktop-portal.service"

    if [[ \
      " ${verified_commands[*]} " == *" pipewire.service "* && \
      " ${verified_commands[*]} " == *" wireplumber.service "* && \
      " ${verified_commands[*]} " == *" xdg-desktop-portal.service "* \
    ]]; then
      verified_commands+=("wayland-screen-sharing-stack")
    else
      missing_commands+=("wayland-screen-sharing-stack")
    fi
  fi

  collect_version "node" node --version
  collect_version "npm" npm --version
  collect_version "gh" gh --version
  collect_version "codex" codex --version
  collect_version "zen-browser" zen-browser --version
  collect_version "google-chrome-stable" google-chrome-stable --version
}

run_install() {
  announce_step "Carregando configuração..."
  load_packages
  create_directories
  ensure_multilib

  if [[ "$SYSTEM_UPDATED" == "1" ]]; then
    announce_detail "O sistema já foi atualizado no bootstrap. A nova atualização completa será ignorada."
  else
    announce_step "Atualizando o sistema..."
    retry_log_only sudo pacman -Syu --noconfirm
  fi

  install_packages_in_order

  if ((${#official_failed[@]} > 0 || ${#aur_failed[@]} > 0)); then
    print_summary
    exit 1
  fi
  announce_step "Ajustando integração desktop..."
  ensure_hyprland_desktop_integration || true
  setup_github_ssh
  announce_step "Validando instalação..."
  verify_installation
  print_summary
}

main() {
  trap cleanup EXIT
  ensure_not_root
  acquire_lock
  init_logging
  announce_step "Validando ambiente..."
  ensure_arch
  require_command pacman
  require_command sudo
  echo "Autenticando sudo..."
  sudo -v

  if [[ -f "$PACKAGE_FILE" ]]; then
    run_install
  else
    run_bootstrap
  fi
}

main "$@"
