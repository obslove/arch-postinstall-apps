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
REFLECTOR_CONNECTION_TIMEOUT="${REFLECTOR_CONNECTION_TIMEOUT:-10}"
REFLECTOR_DOWNLOAD_TIMEOUT="${REFLECTOR_DOWNLOAD_TIMEOUT:-10}"
MIRROR_CHECKPOINT_MAX_AGE_DAYS="${MIRROR_CHECKPOINT_MAX_AGE_DAYS:-7}"
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

ensure_not_root() {
  if [[ "${EUID:-$(id -u)}" -eq 0 ]]; then
    echo "Erro: rode este script como usuário normal, não como root." >&2
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

checkpoint_older_than_days() {
  local checkpoint_name="$1"
  local max_age_days="$2"
  local file_path
  local now_epoch
  local file_epoch
  local max_age_seconds

  file_path="$(checkpoint_file "$checkpoint_name")"
  [[ -f "$file_path" ]] || return 0

  now_epoch="$(date +%s)"
  file_epoch="$(stat -c %Y "$file_path" 2>/dev/null || true)"
  [[ -n "$file_epoch" ]] || return 0

  max_age_seconds=$((max_age_days * 86400))
  (( now_epoch - file_epoch > max_age_seconds ))
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

sanitize_label() {
  printf '%s' "$1" | tr -cs '[:alnum:].@_-' '-'
}

is_wayland_session() {
  [[ "${XDG_SESSION_TYPE:-}" == "wayland" || -n "${WAYLAND_DISPLAY:-}" ]]
}

is_x11_session() {
  [[ "${XDG_SESSION_TYPE:-}" == "x11" || -n "${DISPLAY:-}" ]]
}

is_hyprland_session() {
  [[ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]] || \
    [[ "${XDG_CURRENT_DESKTOP:-}" == *Hyprland* ]] || \
    [[ "${DESKTOP_SESSION:-}" == "hyprland" ]]
}

has_clipboard_utility() {
  command -v wl-copy >/dev/null 2>&1 || \
    command -v xclip >/dev/null 2>&1 || \
    command -v xsel >/dev/null 2>&1 || \
    command -v termux-clipboard-set >/dev/null 2>&1
}

has_session_clipboard_utility() {
  if is_wayland_session; then
    command -v wl-copy >/dev/null 2>&1 && return 0
    command -v termux-clipboard-set >/dev/null 2>&1 && return 0
    return 1
  fi

  if is_x11_session; then
    command -v xclip >/dev/null 2>&1 && return 0
    command -v xsel >/dev/null 2>&1 && return 0
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
  elif is_x11_session; then
    clipboard_package="xclip"
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

open_url_in_background() {
  local url="$1"

  if [[ -z "${DISPLAY:-}" && -z "${WAYLAND_DISPLAY:-}" ]]; then
    return 1
  fi

  if command -v xdg-open >/dev/null 2>&1; then
    nohup xdg-open "$url" >/dev/null 2>&1 &
    return 0
  fi

  if command -v gio >/dev/null 2>&1; then
    nohup gio open "$url" >/dev/null 2>&1 &
    return 0
  fi

  return 1
}

run_gh_auth_flow() {
  local clipboard_args=()

  echo "Abrindo o navegador padrão para autenticação do GitHub..."
  open_url_in_background "https://github.com/login/device" || true
  if ensure_temp_clipboard_utility; then
    clipboard_args+=(--clipboard)
    echo "O código de dispositivo será copiado automaticamente para a área de transferência."
  else
    echo "Clipboard indisponível. Copie o código manualmente no terminal."
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
      announce_detail "Pacotes extras não encontrados em $package_path. Pulando."
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
    announce_detail "multilib já está habilitado."
    return
  fi

  announce_detail "Habilitando multilib..."
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

optimize_mirrors() {
  local current_mirrorlist="/etc/pacman.d/mirrorlist"
  local backup_mirrorlist
  local temp_mirrorlist
  local reflector_status=0

  if has_checkpoint "mirrors" && ! checkpoint_older_than_days "mirrors" "$MIRROR_CHECKPOINT_MAX_AGE_DAYS"; then
    announce_detail "Mirrorlist já atualizada recentemente. Pulando."
    return
  fi

  if has_checkpoint "mirrors"; then
    announce_detail "Checkpoint de mirrors expirado. Atualizando novamente..."
  else
    announce_detail "Mirrorlist ainda não foi atualizada nesta máquina."
  fi

  if ! command -v reflector >/dev/null 2>&1; then
    announce_detail "Instalando reflector..."
    retry_log_only sudo pacman -S --needed --noconfirm reflector
  fi

  announce_step "Atualizando mirrors..."
  backup_mirrorlist="$(mktemp)"
  temp_mirrorlist="$(mktemp)"
  register_cleanup_path "$backup_mirrorlist"
  register_cleanup_path "$temp_mirrorlist"

  sudo cp "$current_mirrorlist" "$backup_mirrorlist"
  if retry_log_only reflector \
    --connection-timeout "$REFLECTOR_CONNECTION_TIMEOUT" \
    --download-timeout "$REFLECTOR_DOWNLOAD_TIMEOUT" \
    --latest 20 \
    --protocol https \
    --sort rate \
    --save "$temp_mirrorlist"; then
    sudo install -m 644 "$temp_mirrorlist" "$current_mirrorlist"
  else
    reflector_status=$?
    if grep -q '^Server' "$temp_mirrorlist"; then
      echo "Aviso: reflector retornou warnings/timeouts, mas gerou uma mirrorlist válida. Continuando com ela."
      sudo install -m 644 "$temp_mirrorlist" "$current_mirrorlist"
    else
      echo "Aviso: reflector falhou sem gerar mirrorlist válida. Restaurando mirrorlist anterior."
      sudo install -m 644 "$backup_mirrorlist" "$current_mirrorlist"
      rm -f "$backup_mirrorlist" "$temp_mirrorlist"
      return "$reflector_status"
    fi
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

  announce_detail "Nenhum helper AUR encontrado. Vou instalar o yay..."
  if ! install_yay; then
    echo "Erro: não foi possível preparar um helper AUR (yay)." >&2
    return 1
  fi
  announce_detail "Usando helper AUR: $aur_helper"
}

github_ssh_ready() {
  has_checkpoint "github_ssh" && [[ -f "${SSH_KEY_PATH}.pub" ]]
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
    announce_detail "Remote origin personalizado detectado em $repo_dir. Mantendo configuração atual."
    return
  fi

  if [[ "$current_origin_url" != "$desired_origin_url" ]]; then
    git -C "$repo_dir" remote set-url origin "$desired_origin_url"
  fi
}

install_packages_in_order() {
  local package
  local announced_aur_absence=0
  local shown_pacman_step=0
  local shown_aur_step=0

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

    if pacman -Si "$package" >/dev/null 2>&1; then
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
      announce_detail "Encontrado o primeiro pacote AUR na lista."
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
    announce_detail "Nenhum pacote AUR na lista. Pulando etapa do AUR."
  fi
}

print_summary() {
  local host_name
  local repo_path
  local version_line

  host_name="$(get_host_name)"
  repo_path="$SCRIPT_DIR"

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
    echo "Branch: $REPO_BRANCH"
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
Branch: $REPO_BRANCH
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
- mirrors: $(if has_checkpoint "mirrors"; then echo concluido; else echo pendente; fi)
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

setup_codex_cli() {
  local codex_path_line="export PATH=\"\$HOME/Codex/bin:\$PATH\""
  local fish_codex_path_marker="if not contains \"\$HOME/Codex/bin\" \$PATH"
  local fish_codex_path_block="if not contains \"\$HOME/Codex/bin\" \$PATH
    set -gx PATH \"\$HOME/Codex/bin\" \$PATH
end"

  if has_checkpoint "codex_cli" && command -v codex >/dev/null 2>&1; then
    announce_detail "Codex CLI já configurado. Pulando."
    return
  fi

  require_command npm

  announce_detail "Configurando npm prefix em $HOME/Codex..."
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
    announce_detail "Chave SSH já existe em $SSH_KEY_PATH"
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
  local existing_keys
  local key_id
  local key_ids

  current_key="$(<"${SSH_KEY_PATH}.pub")"
  if ! existing_keys="$(gh api user/keys --jq '.[] | [.id, .key] | @tsv' 2>/dev/null)"; then
    announce_detail "Permissão admin:public_key ausente no gh. Vou renovar a autenticação."
    if ! run_gh_auth_flow auth refresh -h github.com -s admin:public_key; then
      echo "Aviso: não foi possível renovar o escopo admin:public_key no gh."
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
    announce_detail "Chave SSH atual já está cadastrada no GitHub."
    return
  fi

  if [[ -z "$current_key_id" ]]; then
    announce_detail "Enviando chave SSH para o GitHub..."
    current_key_id="$(retry gh api user/keys --method POST -f "title=obslove" -f "key=$current_key" --jq '.id')"
  else
    announce_detail "Chave SSH atual já existe no GitHub."
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
    announce_step "Atualizando repositório..."
    if repo_is_dirty; then
      echo "Aviso: repositório local tem mudanças. Pulando atualização automática."
      return
    fi

    ensure_repo_origin_remote "$INSTALL_DIR"

    if retry_log_only git -C "$INSTALL_DIR" fetch origin; then
      fetched_origin=1
    else
      echo "Aviso: falha ao buscar atualizações de origin. Vou tentar usar a cópia local."
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
      echo "Aviso: pulando 'git pull' porque o fetch de origin falhou. Continuando com a branch local."
      return
    fi

    if ! retry_log_only git -C "$INSTALL_DIR" pull --ff-only origin "$REPO_BRANCH"; then
      echo "Aviso: falha ao atualizar '$REPO_BRANCH' via 'git pull --ff-only'. Continuando com a cópia atual."
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
  if has_checkpoint "github_ssh" && command -v gh >/dev/null 2>&1 && gh auth status >/dev/null 2>&1 && [[ -f "${SSH_KEY_PATH}.pub" ]]; then
    ensure_repo_origin_remote "$SCRIPT_DIR"
    announce_detail "GitHub SSH já configurado. Pulando."
    return
  fi

  announce_step "Configurando GitHub SSH..."
  if ! retry_log_only sudo pacman -S --needed --noconfirm github-cli openssh; then
    echo "Aviso: não foi possível instalar github-cli/openssh. Pulando configuração do GitHub."
    return
  fi

  if ! command -v gh >/dev/null 2>&1 || ! command -v ssh-keygen >/dev/null 2>&1; then
    echo "Aviso: github-cli ou ssh-keygen indisponível. Pulando configuração do GitHub."
    return
  fi

  ensure_ssh_key
  if ! ensure_github_auth; then
    cleanup_temp_clipboard_utility || true
    echo "Aviso: autenticação do GitHub não concluída. Pulando upload da chave SSH."
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

  if is_x11_session; then
    if command -v xclip >/dev/null 2>&1 || command -v xsel >/dev/null 2>&1; then
      verified_commands+=("x11-clipboard")
    else
      missing_commands+=("x11-clipboard")
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
  optimize_mirrors

  if [[ "$SYSTEM_UPDATED" == "1" ]]; then
    announce_detail "Sistema já atualizado no bootstrap. Pulando nova atualização completa."
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
