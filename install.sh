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
REPO_BRANCH="main"
REPOSITORIES_DIR="${REPOSITORIES_DIR:-$HOME/Repositories}"
INSTALL_DIR="${BOOTSTRAP_DIR:-$REPOSITORIES_DIR/arch-postinstall-apps}"
YAY_REPO_DIR="${YAY_REPO_DIR:-$REPOSITORIES_DIR/yay}"
YAY_SNAPSHOT_URL="${YAY_SNAPSHOT_URL:-https://aur.archlinux.org/cgit/aur.git/snapshot/yay.tar.gz}"
SSH_KEY_PATH="${SSH_KEY_PATH:-$HOME/.ssh/id_ed25519}"
GITHUB_SSH_KEY_TITLE=""
LOG_FILE="${POSTINSTALL_LOG_FILE:-$HOME/Backups/arch-postinstall.log}"
SUMMARY_FILE="${POSTINSTALL_SUMMARY_FILE:-$HOME/Backups/arch-postinstall-summary.txt}"
CHECK_ONLY=0
SKIP_GITHUB_SSH=0
RETRY_ATTEMPTS=1
RETRY_DELAY_SECONDS=0
STEP_OUTPUT_ONLY=1
STATE_DIR="${POSTINSTALL_STATE_DIR:-${XDG_STATE_HOME:-$HOME/.local/state}/arch-postinstall-apps}"
LOCK_DIR="${POSTINSTALL_LOCK_DIR:-$STATE_DIR/lock}"
LOCK_HELD="${POSTINSTALL_LOCK_HELD:-0}"
SYSTEM_UPDATED="${POSTINSTALL_SYSTEM_UPDATED:-0}"
BOOTSTRAP_PACKAGES=(
  ca-certificates
  git
  curl
  tar
)

official_packages=()
aur_packages=()
official_failed=()
aur_failed=()
support_packages=()
environment_packages=()
packages=()
aur_helper=""
aur_helper_status="não preparado"
cleanup_paths=()
verified_commands=()
missing_commands=()
version_info=()
temp_clipboard_package=""
official_repo_metadata_checked=0
official_repo_metadata_ready=0
github_ssh_status="pendente"
desktop_integration_status="pendente"
step_counter=0
step_open=0
step_total=0
style_reset=""
style_step=""
style_detail=""
style_success=""
style_warning=""
style_error=""
style_muted=""

if [[ -t 1 && -z "${NO_COLOR:-}" ]]; then
  style_reset=$'\033[0m'
  style_step=$'\033[1;36m'
  style_detail=$'\033[0;37m'
  style_success=$'\033[1;32m'
  style_warning=$'\033[1;33m'
  style_error=$'\033[1;31m'
  style_muted=$'\033[0;90m'
fi

print_usage() {
  cat <<'EOF'
Uso:
  bash install.sh [opções]
  curl -fsSL https://obslove.dev | bash -s -- [opções]

Opções:
  -c, --check             Valida o ambiente sem instalar nem alterar o sistema.
  -g, --no-gh             Pula a etapa de GitHub SSH.
  -t, --ssh-title NOME    Define o título da chave SSH enviada ao GitHub.
  -v, --verbose           Desativa o modo resumido e mostra a saída completa.
  -h, --help              Exibe esta ajuda.
EOF
}

parse_cli_args() {
  while (($# > 0)); do
    case "$1" in
      -c|--check)
        CHECK_ONLY=1
        shift
        ;;
      -g|--no-gh)
        SKIP_GITHUB_SSH=1
        shift
        ;;
      -t|--ssh-title)
        [[ $# -ge 2 ]] || {
          printf 'Erro: faltou informar o valor de %s.\n' "$1" >&2
          exit 1
        }
        GITHUB_SSH_KEY_TITLE="$2"
        shift 2
        ;;
      --ssh-title=*)
        GITHUB_SSH_KEY_TITLE="${1#*=}"
        shift
        ;;
      -v|--verbose)
        STEP_OUTPUT_ONLY=0
        shift
        ;;
      -h|--help)
        print_usage
        exit 0
        ;;
      --)
        shift
        break
        ;;
      -*)
        printf 'Erro: opção desconhecida: %s\n' "$1" >&2
        printf 'Use --help para ver as opções disponíveis.\n' >&2
        exit 1
        ;;
      *)
        printf 'Erro: argumento não reconhecido: %s\n' "$1" >&2
        exit 1
        ;;
    esac
  done

  if (($# > 0)); then
    printf 'Erro: argumentos extras não reconhecidos: %s\n' "$*" >&2
    exit 1
  fi
}

ensure_not_root() {
  if [[ "${EUID:-$(id -u)}" -eq 0 ]]; then
    announce_error "Execute este script como usuário comum, e não como root."
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
    announce_warning "Foi detectado um lock órfão. Limpando a execução anterior."
    rm -rf "$LOCK_DIR"
    if mkdir "$LOCK_DIR" 2>/dev/null; then
      printf '%s\n' "$$" >"$LOCK_DIR/pid"
      register_cleanup_path "$LOCK_DIR"
      export POSTINSTALL_LOCK_HELD=1
      return
    fi
  fi

  announce_error "Já existe outra execução do script em andamento."
  if [[ -f "$LOCK_DIR/pid" ]]; then
    announce_error "PID atual do lock: $(<"$LOCK_DIR/pid")"
  fi
  exit 1
}

register_cleanup_path() {
  cleanup_paths+=("$1")
}

append_array_item() {
  local array_name="$1"
  local value="$2"
  local existing
  # shellcheck disable=SC2178
  declare -n target_array="$array_name"

  for existing in "${target_array[@]}"; do
    [[ "$existing" == "$value" ]] && return 0
  done

  target_array+=("$value")
}

mark_support_package() {
  append_array_item support_packages "$1"
}

mark_environment_package() {
  append_array_item environment_packages "$1"
}

mark_verified_item() {
  append_array_item verified_commands "$1"
}

mark_missing_item() {
  append_array_item missing_commands "$1"
}

package_is_installed() {
  pacman -Q "$1" >/dev/null 2>&1
}

github_ssh_expected() {
  [[ "$SKIP_GITHUB_SSH" != "1" ]]
}

collect_missing_packages() {
  local array_name="$1"
  shift
  local package_name
  # shellcheck disable=SC2178
  declare -n target_array="$array_name"

  target_array=()
  for package_name in "$@"; do
    if ! package_is_installed "$package_name"; then
      target_array+=("$package_name")
    fi
  done
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

style_text() {
  local style="$1"
  local text="$2"

  if [[ -z "$style" ]]; then
    printf '%s' "$text"
    return 0
  fi

  printf '%s%s%s' "$style" "$text" "$style_reset"
}

emit_notice() {
  local symbol="$1"
  local style="$2"
  local message="$3"
  local line_prefix=""

  if [[ "$step_open" == "1" ]]; then
    line_prefix="│  "
  fi

  printf '%s%s %s\n' "$line_prefix" "$(style_text "$style" "$symbol")" "$message"
}

set_step_total() {
  step_total="$1"
}

announce_step() {
  local title="$1"
  local header=""

  close_step_block
  step_counter=$((step_counter + 1))
  if (( step_total > 0 )); then
    header=$(printf 'Etapa %02d/%02d • %s' "$step_counter" "$step_total" "$title")
  else
    header=$(printf 'Etapa %02d • %s' "$step_counter" "$title")
  fi
  echo
  printf '%s %s\n' "$(style_text "$style_step" "╭─")" "$(style_text "$style_step" "$header")"
  step_open=1
}

announce_detail() {
  if [[ "$STEP_OUTPUT_ONLY" == "1" ]]; then
    printf '%s\n' "$1" >>"$LOG_FILE"
    if [[ "$1" == *"Etapa ignorada."* || "$1" == Instalando\ via\ pacman:* || "$1" == Instalando\ via\ AUR:* ]]; then
      return 0
    fi
    printf '│  %s %s\n' "$(style_text "$style_detail" "•")" "$1"
    return 0
  fi

  printf '│  %s %s\n' "$(style_text "$style_detail" "•")" "$1"
}

announce_warning() {
  printf '%s\n' "$1" >>"$LOG_FILE"
  emit_notice "!" "$style_warning" "$1"
}

announce_error() {
  printf '%s\n' "$1" >>"$LOG_FILE"
  emit_notice "x" "$style_error" "$1"
}

announce_prompt() {
  printf '%s\n' "$1" >>"$LOG_FILE"
  emit_notice "?" "$style_step" "$1"
}

run_log_only() {
  if [[ "$STEP_OUTPUT_ONLY" == "1" ]]; then
    "$@" >>"$LOG_FILE" 2>&1
    return
  fi

  "$@" 2>&1 | tee -a "$LOG_FILE" | sed 's/^/│    /'
  return "${PIPESTATUS[0]}"
}

print_summary_section() {
  local title="$1"
  echo "│"
  printf '│  %s\n' "$(style_text "$style_step" "$title")"
}

print_summary_item() {
  local label="$1"
  local value="$2"
  local label_length=0
  local padding_width=22

  label_length="$(printf '%s' "$label" | wc -m | tr -d '[:space:]')"
  if [[ -z "$label_length" ]]; then
    label_length=0
  fi
  if (( label_length < padding_width )); then
    printf '│  %s %s%*s %s\n' "$(style_text "$style_detail" "•")" "$label" "$((padding_width - label_length))" "" "$value"
    return 0
  fi

  printf '│  %s %s %s\n' "$(style_text "$style_detail" "•")" "$label" "$value"
}

close_step_block() {
  if [[ "$step_open" != "1" ]]; then
    return 0
  fi

  style_text "$style_muted" "╰─"
  printf '\n'
  step_open=0
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
    announce_error "Comando obrigatório não encontrado: $1"
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

build_ssh_key_title() {
  local github_login=""

  if [[ -n "$GITHUB_SSH_KEY_TITLE" ]]; then
    printf '%s\n' "$GITHUB_SSH_KEY_TITLE"
    return
  fi

  if command -v gh >/dev/null 2>&1; then
    github_login="$(gh api user --jq '.login' 2>/dev/null || true)"
    if [[ -n "$github_login" ]]; then
      printf '%s\n' "$github_login"
      return
    fi
  fi

  printf '%s\n' "$USER"
}

is_wayland_session() {
  [[ "${XDG_SESSION_TYPE:-}" == "wayland" || -n "${WAYLAND_DISPLAY:-}" ]]
}

is_hyprland_session() {
  [[ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]] || \
    [[ "${XDG_CURRENT_DESKTOP:-}" == *Hyprland* ]] || \
    [[ "${DESKTOP_SESSION:-}" == "hyprland" ]]
}

is_supported_session() {
  is_wayland_session && is_hyprland_session
}

ensure_supported_session() {
  if is_supported_session; then
    return 0
  fi

  announce_error "Este script foi ajustado para Wayland com Hyprland."
  announce_error "Sessão atual: XDG_SESSION_TYPE='${XDG_SESSION_TYPE:-}', XDG_CURRENT_DESKTOP='${XDG_CURRENT_DESKTOP:-}', DESKTOP_SESSION='${DESKTOP_SESSION:-}'"
  exit 1
}

ensure_temp_clipboard_utility() {
  local missing_packages=()

  if command -v wl-copy >/dev/null 2>&1; then
    return 0
  fi

  collect_missing_packages missing_packages wl-clipboard
  if ((${#missing_packages[@]} == 0)); then
    return 0
  fi

  announce_detail "Instalando wl-clipboard temporariamente para copiar o código do GitHub..."
  if ! retry_log_only sudo pacman -S --needed --noconfirm "${missing_packages[@]}"; then
    announce_warning "Não foi possível instalar wl-clipboard. Continuando sem cópia automática."
    return 1
  fi

  temp_clipboard_package="wl-clipboard"
  return 0
}

cleanup_temp_clipboard_utility() {
  if [[ -z "$temp_clipboard_package" ]]; then
    return 0
  fi

  announce_detail "Removendo $temp_clipboard_package instalado temporariamente..."
  if ! retry_log_only sudo pacman -Rns --noconfirm "$temp_clipboard_package"; then
    announce_warning "Não foi possível remover $temp_clipboard_package automaticamente."
    return 1
  fi

  temp_clipboard_package=""
}

desktop_integration_ready() {
  local package_name

  for package_name in \
    pipewire \
    wireplumber \
    xdg-utils \
    xdg-desktop-portal \
    xdg-desktop-portal-gtk \
    xdg-desktop-portal-hyprland; do
    if ! pacman -Q "$package_name" >/dev/null 2>&1; then
      return 1
    fi
  done

  return 0
}

ensure_desktop_integration() {
  local required_packages=(
    pipewire
    wireplumber
    xdg-utils
    xdg-desktop-portal
    xdg-desktop-portal-gtk
    xdg-desktop-portal-hyprland
  )
  local missing_packages=()

  environment_packages=()
  for package_name in "${required_packages[@]}"; do
    mark_environment_package "$package_name"
  done

  if desktop_integration_ready; then
    desktop_integration_status="ignorada por já estar pronta"
    if ! has_checkpoint "desktop_integration" && ! mark_checkpoint "desktop_integration"; then
      announce_warning "Não foi possível registrar o checkpoint da integração desktop."
    fi
    announce_detail "A integração desktop já está preparada. Etapa ignorada."
    return 0
  fi

  collect_missing_packages missing_packages "${required_packages[@]}"
  announce_detail "Garantindo integração desktop..."
  if ! retry_log_only sudo pacman -S --needed --noconfirm "${missing_packages[@]}"; then
    desktop_integration_status="falhou"
    announce_error "Não foi possível instalar a integração desktop."
    return 1
  fi

  if ! mark_checkpoint "desktop_integration"; then
    desktop_integration_status="falhou"
    announce_error "Não foi possível registrar o checkpoint da integração desktop."
    return 1
  fi

  desktop_integration_status="concluída"
}

run_gh_auth_flow() {
  local clipboard_args=()

  announce_prompt "Iniciando a autenticação do GitHub..."
  if ensure_temp_clipboard_utility; then
    clipboard_args+=(--clipboard)
    announce_detail "O código de dispositivo será copiado automaticamente para a área de transferência."
  else
    announce_warning "Área de transferência indisponível. Copie o código manualmente no terminal."
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
    announce_error "Este script foi feito para Arch Linux."
    exit 1
  fi
}

load_packages() {
  [[ -f "$PACKAGE_FILE" ]] || {
    announce_error "Lista de pacotes não encontrada em $PACKAGE_FILE"
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
    announce_error "Não foi possível habilitar multilib automaticamente."
    exit 1
  fi

  if ! run_log_only sudo pacman -Syy --noconfirm; then
    announce_error "Não foi possível sincronizar os bancos de dados do pacman após habilitar multilib."
    exit 1
  fi
}

detect_aur_helper() {
  if command -v yay >/dev/null 2>&1; then
    aur_helper="yay"
    aur_helper_status="yay (reutilizado)"
    return 0
  fi

  if command -v paru >/dev/null 2>&1; then
    aur_helper="paru"
    aur_helper_status="paru (fallback)"
    return 0
  fi

  aur_helper=""
  aur_helper_status="indisponível"
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
  if [[ "$official_repo_metadata_checked" == "1" ]]; then
    [[ "$official_repo_metadata_ready" == "1" ]]
    return
  fi

  official_repo_metadata_checked=1
  if ! pacman -Slq >/dev/null 2>&1; then
    official_repo_metadata_ready=0
    announce_error "Não foi possível carregar os metadados dos repositórios oficiais do pacman."
    return 1
  fi

  official_repo_metadata_ready=1
}

package_exists_in_official_repos() {
  local package="$1"

  if ! refresh_official_repo_index; then
    return 2
  fi

  if pacman -Si -- "$package" >/dev/null 2>&1; then
    return 0
  fi

  return 1
}

install_yay() {
  local archive_file
  local missing_packages=()
  local status=0

  mark_support_package "base-devel"
  mark_support_package "yay"
  mkdir -p "$REPOSITORIES_DIR"
  collect_missing_packages missing_packages base-devel
  if ((${#missing_packages[@]} > 0)); then
    if ! retry_log_only sudo pacman -S --needed --noconfirm "${missing_packages[@]}"; then
      return 1
    fi
  fi
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
      aur_helper_status="yay (instalado nesta execução)"
    else
      status=$?
    fi
  fi

  return "$status"
}

ensure_aur_helper() {
  if command -v yay >/dev/null 2>&1; then
    aur_helper="yay"
    aur_helper_status="yay (reutilizado)"
    announce_detail "Usando helper AUR: $aur_helper"
    return 0
  fi

  announce_detail "O yay será instalado e usado como helper AUR padrão."
  if ! install_yay; then
    if detect_aur_helper; then
      announce_warning "Não foi possível instalar o yay. O script usará o helper AUR disponível: $aur_helper."
      return 0
    fi

    announce_error "Não foi possível preparar um helper AUR (yay)."
    return 1
  fi

  aur_helper="yay"
  aur_helper_status="yay (instalado nesta execução)"
  announce_detail "Usando helper AUR: $aur_helper"
}

github_ssh_ready() {
  [[ -f "${SSH_KEY_PATH}.pub" ]] || return 1
  command -v gh >/dev/null 2>&1 || return 1
  gh auth status >/dev/null 2>&1 || return 1
  has_checkpoint "github_ssh" || return 1
  github_has_expected_ssh_key_title
}

github_has_current_ssh_key() {
  local current_key
  local existing_keys

  [[ -f "${SSH_KEY_PATH}.pub" ]] || return 1
  current_key="$(current_public_ssh_key)"
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
  local package_origin_status
  local shown_pacman_step=0
  local shown_aur_step=0
  local official_target_count=0
  local aur_target_count=0

  if ! refresh_official_repo_index; then
    announce_error "Não foi possível preparar o índice de pacotes oficiais antes da instalação."
    return 1
  fi

  official_packages=()
  aur_packages=()

  if [[ "$STEP_OUTPUT_ONLY" == "1" ]]; then
    for package in "${packages[@]}"; do
      [[ "$package" == "codex" ]] && continue
      if package_exists_in_official_repos "$package"; then
        official_target_count=$((official_target_count + 1))
      else
        package_origin_status=$?
        if [[ "$package_origin_status" == "2" ]]; then
          announce_error "Não foi possível classificar o pacote '$package' entre repositório oficial e AUR."
          return 1
        fi
        aur_target_count=$((aur_target_count + 1))
      fi
    done
  fi

  for package in "${packages[@]}"; do
    case "$package" in
      codex)
        announce_step "Configurando Codex CLI..."
        if ! setup_codex_cli; then
          official_failed+=("codex")
        fi
        continue
        ;;
    esac

    if package_exists_in_official_repos "$package"; then
      package_origin_status=0
    else
      package_origin_status=$?
    fi

    if [[ "$package_origin_status" == "0" ]]; then
      official_packages+=("$package")
      if [[ "$shown_pacman_step" == "0" ]]; then
        announce_step "Instalando apps oficiais..."
        if (( official_target_count > 0 )); then
          announce_detail "$official_target_count item(ns) previsto(s) na lista principal oficial."
        fi
        shown_pacman_step=1
      fi
      announce_detail "Instalando via pacman: $package"
      if retry_log_only sudo pacman -S --needed --noconfirm "$package"; then
        continue
      fi

      official_failed+=("$package")
      continue
    fi

    if [[ "$package_origin_status" == "2" ]]; then
      announce_error "Não foi possível classificar o pacote '$package' entre repositório oficial e AUR."
      return 1
    fi

    aur_packages+=("$package")
    if ! ensure_aur_helper; then
      aur_failed+=("$package")
      continue
    fi

    if [[ "$shown_aur_step" == "0" ]]; then
      announce_step "Instalando apps AUR..."
      if (( aur_target_count > 0 )); then
        announce_detail "$aur_target_count item(ns) previsto(s) na lista principal AUR."
      fi
      shown_aur_step=1
    fi
    announce_detail "Instalando via AUR: $package"
    if retry_log_only "$aur_helper" -S --needed --noconfirm "$package"; then
      continue
    fi

    aur_failed+=("$package")
  done
}

print_summary() {
  local host_name
  local actual_branch
  local actual_commit
  local repo_path
  local origin_status="indisponível"
  local completed_actions=()
  local execution_mode="instalação"
  local changes_applied="sim"
  local version_line

  if [[ "$CHECK_ONLY" == "1" ]]; then
    execution_mode="verificação"
    changes_applied="não"
  fi

  host_name="$(get_host_name)"
  actual_branch="$(get_repo_branch "$SCRIPT_DIR" 2>/dev/null || printf '%s\n' "$REPO_BRANCH")"
  actual_commit="$(current_repo_commit_short "$SCRIPT_DIR")"
  repo_path="$SCRIPT_DIR"
  origin_status="$(current_repo_origin_status "$SCRIPT_DIR")"

  if has_checkpoint "codex_cli"; then
    completed_actions+=("codex_cli")
  fi
  if has_checkpoint "desktop_integration"; then
    completed_actions+=("desktop_integration")
  fi
  if has_checkpoint "github_ssh"; then
    completed_actions+=("github_ssh")
  fi

  close_step_block

  if [[ "$STEP_OUTPUT_ONLY" == "1" ]]; then
    echo
    printf '%s %s\n' "$(style_text "$style_success" "╭─")" "$(style_text "$style_success" "Concluído")"
    print_summary_section "Arquivos"
    print_summary_item "Log:" "$LOG_FILE"
    print_summary_item "Resumo:" "$SUMMARY_FILE"
    print_summary_section "Estado"
    print_summary_item "Modo:" "$execution_mode"
    print_summary_item "Alterações aplicadas:" "$changes_applied"
    print_summary_item "Branch:" "$actual_branch"
    print_summary_item "Commit:" "$actual_commit"
    echo "│"
    style_text "$style_muted" "╰─ Fim"
    printf '\n'
  else
    echo
    printf '%s %s\n' "$(style_text "$style_success" "╭─")" "$(style_text "$style_success" "Concluído")"
    print_summary_section "Arquivos"
    print_summary_item "Log:" "$LOG_FILE"
    print_summary_item "Resumo:" "$SUMMARY_FILE"
    print_summary_section "Estado"
    print_summary_item "Modo:" "$execution_mode"
    print_summary_item "Alterações aplicadas:" "$changes_applied"
    print_summary_item "Hostname:" "$host_name"
    print_summary_item "Repositório:" "$repo_path"
    print_summary_item "Branch:" "$actual_branch"
    print_summary_item "Commit:" "$actual_commit"
    print_summary_item "Origin:" "$origin_status"
    print_summary_section "Pacotes e configuração"
    print_summary_item "Lista principal via pacman:" "${official_packages[*]:-nenhum}"
    print_summary_item "Lista principal via AUR:" "${aur_packages[*]:-nenhum}"
    print_summary_item "Dependências de suporte:" "${support_packages[*]:-nenhuma}"
    print_summary_item "Ambiente gráfico:" "${environment_packages[*]:-nenhuma}"
    print_summary_item "Configurações explícitas:" "${completed_actions[*]:-nenhuma}"
    print_summary_item "GitHub SSH esperado:" "$(if github_ssh_expected; then echo sim; else echo não; fi)"
    print_summary_item "GitHub SSH:" "$github_ssh_status"
    print_summary_item "Integração desktop:" "$desktop_integration_status"
    print_summary_item "Helper AUR:" "${aur_helper_status:-indisponível}"
    print_summary_section "Verificação"
    print_summary_item "Falhas pacman:" "${official_failed[*]:-nenhuma}"
    print_summary_item "Falhas AUR:" "${aur_failed[*]:-nenhuma}"
    print_summary_item "Verificados:" "${verified_commands[*]:-nenhum}"
    print_summary_item "Ausentes:" "${missing_commands[*]:-nenhum}"
    if ((${#version_info[@]} == 0)); then
      print_summary_item "Versões:" "nenhuma"
    else
      print_summary_section "Versões"
      for version_line in "${version_info[@]}"; do
        echo "│    $(style_text "$style_detail" "•") $version_line"
      done
    fi
    echo "│"
    style_text "$style_muted" "╰─ Fim"
    printf '\n'
  fi

  mkdir -p "$(dirname "$SUMMARY_FILE")"
  cat >"$SUMMARY_FILE" <<EOF
Data: $(date '+%Y-%m-%d %H:%M:%S %z')
Modo: $execution_mode
Alterações aplicadas: $changes_applied
Log: $LOG_FILE
Hostname: $host_name
Repositório: $repo_path
Branch: $actual_branch
Commit: $actual_commit
Origin: $origin_status
Itens da lista principal tratados via pacman: ${official_packages[*]:-nenhum}
Itens da lista principal tratados via AUR: ${aur_packages[*]:-nenhum}
Dependências de suporte tratadas: ${support_packages[*]:-nenhuma}
Dependências do ambiente gráfico tratadas: ${environment_packages[*]:-nenhuma}
Configurações explícitas: ${completed_actions[*]:-nenhuma}
GitHub SSH esperado: $(if github_ssh_expected; then echo sim; else echo não; fi)
GitHub SSH: $github_ssh_status
Integração desktop: $desktop_integration_status
Helper AUR: ${aur_helper_status:-indisponível}
Falhas pacman: ${official_failed[*]:-nenhuma}
Falhas AUR: ${aur_failed[*]:-nenhuma}
Verificados: ${verified_commands[*]:-nenhum}
Ausentes: ${missing_commands[*]:-nenhum}
Versões:
$(if ((${#version_info[@]} == 0)); then echo "- nenhuma"; else printf '%s\n' "${version_info[@]/#/- }"; fi)
Checkpoints:
- codex_cli: $(if has_checkpoint "codex_cli"; then echo concluido; else echo pendente; fi)
- desktop_integration: $(if has_checkpoint "desktop_integration"; then echo concluido; else echo pendente; fi)
- github_ssh: $(if has_checkpoint "github_ssh"; then echo concluido; else echo pendente; fi)
EOF

  if [[ "$SCRIPT_DIR" != "$INSTALL_DIR" ]]; then
    printf 'Clone gerenciado: %s\n' "$INSTALL_DIR" >>"$SUMMARY_FILE"
  fi
}

current_repo_origin_status() {
  local repo_dir="$1"
  local current_origin_url=""

  current_origin_url="$(git -C "$repo_dir" remote get-url origin 2>/dev/null || true)"
  case "$current_origin_url" in
    "$REPO_SSH_URL")
      printf '%s\n' "ssh"
      ;;
    "$REPO_HTTPS_URL")
      printf '%s\n' "https"
      ;;
    "")
      printf '%s\n' "ausente"
      ;;
    *)
      printf '%s\n' "personalizado"
      ;;
  esac
}

build_bootstrap_args() {
  local forwarded_args=()

  if [[ "$CHECK_ONLY" == "1" ]]; then
    forwarded_args+=("--check")
  fi
  if [[ "$SKIP_GITHUB_SSH" == "1" ]]; then
    forwarded_args+=("--no-gh")
  fi
  if [[ "$STEP_OUTPUT_ONLY" == "0" ]]; then
    forwarded_args+=("--verbose")
  fi
  if [[ -n "$GITHUB_SSH_KEY_TITLE" ]]; then
    forwarded_args+=("--ssh-title" "$GITHUB_SSH_KEY_TITLE")
  fi

  if ((${#forwarded_args[@]} > 0)); then
    printf '%s\n' "${forwarded_args[@]}"
  fi
}

current_repo_commit_short() {
  local repo_dir="$1"
  local commit_hash=""

  commit_hash="$(git -C "$repo_dir" rev-parse --short HEAD 2>/dev/null || true)"
  [[ -n "$commit_hash" ]] || {
    printf '%s\n' "indisponível"
    return 0
  }

  printf '%s\n' "$commit_hash"
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
  if ! run_log_only npm config set prefix "$HOME/Codex"; then
    announce_error "Não foi possível configurar o prefixo do npm para o Codex CLI."
    return 1
  fi

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
  if ! retry_log_only npm install -g @openai/codex; then
    announce_error "Não foi possível instalar o Codex CLI."
    return 1
  fi

  if ! mark_checkpoint "codex_cli"; then
    announce_error "Não foi possível registrar o checkpoint do Codex CLI."
    return 1
  fi
}

ensure_ssh_key() {
  local ssh_dir
  local host_name
  local key_comment

  ssh_dir="$(dirname "$SSH_KEY_PATH")"
  mkdir -p "$ssh_dir"
  chmod 700 "$ssh_dir"

  if [[ -f "$SSH_KEY_PATH" ]]; then
    if [[ ! -f "${SSH_KEY_PATH}.pub" ]]; then
      announce_detail "A chave pública SSH não foi encontrada. Recriando ${SSH_KEY_PATH}.pub..."
      if ! ssh-keygen -y -f "$SSH_KEY_PATH" >"${SSH_KEY_PATH}.pub"; then
        announce_error "Não foi possível recriar a chave pública SSH."
        return 1
      fi
      chmod 644 "${SSH_KEY_PATH}.pub"
    fi
    announce_detail "A chave SSH já existe em $SSH_KEY_PATH."
    return 0
  fi

  key_comment="$(git config --global user.email 2>/dev/null || true)"
  if [[ -z "$key_comment" ]]; then
    host_name="$(sanitize_label "$(get_host_name)")"
    key_comment="${USER}@${host_name}"
  fi

  announce_detail "Criando chave SSH em $SSH_KEY_PATH..."
  if ! ssh-keygen -t ed25519 -C "$key_comment" -f "$SSH_KEY_PATH" -N ""; then
    announce_error "Não foi possível criar a chave SSH."
    return 1
  fi

  return 0
}

ensure_github_auth() {
  if gh auth status >/dev/null 2>&1; then
    announce_detail "GitHub CLI já autenticado."
    return
  fi

  announce_prompt "Autenticando no GitHub com gh..."
  run_gh_auth_flow auth login --web --git-protocol ssh --scopes admin:public_key
}

upload_ssh_key() {
  local current_key
  local current_key_id=""
  local current_key_title=""
  local existing_keys
  local key_id
  local key_title_from_api
  local key_value
  local key_title

  if ! current_key="$(current_public_ssh_key)"; then
    announce_warning "A chave pública SSH atual não está disponível."
    return 1
  fi
  if [[ -z "$current_key" ]]; then
    announce_warning "A chave pública SSH atual está vazia ou inválida."
    return 1
  fi
  key_title="$(build_ssh_key_title)"
  if ! existing_keys="$(gh api user/keys --jq '.[] | [.id, .title, .key] | @tsv' 2>/dev/null)"; then
    announce_detail "A permissão admin:public_key não está disponível no gh. A autenticação será renovada."
    if ! run_gh_auth_flow auth refresh -h github.com -s admin:public_key; then
      announce_warning "Não foi possível renovar o escopo admin:public_key no gh."
      return 1
    fi

    if ! existing_keys="$(gh api user/keys --jq '.[] | [.id, .title, .key] | @tsv' 2>/dev/null)"; then
      announce_warning "O gh continua sem acesso para gerenciar chaves SSH no GitHub."
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
    if ! retry gh api --method DELETE "user/keys/$current_key_id"; then
      announce_warning "Não foi possível remover a chave SSH antiga com título incorreto."
      return 1
    fi
    current_key_id=""
  fi

  if [[ -z "$current_key_id" ]]; then
    announce_detail "Enviando a chave SSH ao GitHub..."
    if ! current_key_id="$(retry gh api user/keys --method POST -f "title=$key_title" -f "key=$current_key" --jq '.id')"; then
      announce_warning "Não foi possível enviar a chave SSH atual ao GitHub."
      return 1
    fi
    if [[ -z "$current_key_id" || ! "$current_key_id" =~ ^[0-9]+$ ]]; then
      announce_warning "O GitHub não retornou um identificador válido para a chave SSH enviada."
      return 1
    fi
  else
    announce_detail "A chave SSH atual já existe no GitHub."
  fi

  if ! github_has_expected_ssh_key_title; then
    announce_warning "A chave SSH foi enviada, mas o título esperado no GitHub não pôde ser confirmado."
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
        announce_error "O clone gerenciado está com mudanças locais na branch '$current_branch'."
        announce_error "Não dá para executar com segurança a branch solicitada '$REPO_BRANCH' sem limpar ou mover essas mudanças."
        exit 1
      fi

      announce_warning "O repositório local tem alterações. A atualização automática será ignorada."
      return
    fi

    if ! ensure_repo_origin_remote "$INSTALL_DIR"; then
      announce_error "Não foi possível ajustar o remoto origin do clone gerenciado."
      exit 1
    fi

    if retry_log_only git -C "$INSTALL_DIR" fetch origin; then
      fetched_origin=1
    else
      announce_warning "Falha ao buscar atualizações de origin. O script tentará usar a cópia local."
    fi

    if git -C "$INSTALL_DIR" show-ref --verify --quiet "refs/heads/$REPO_BRANCH"; then
      if ! run_log_only git -C "$INSTALL_DIR" checkout "$REPO_BRANCH"; then
        announce_error "Não foi possível trocar para a branch local '$REPO_BRANCH'."
        exit 1
      fi
    elif git -C "$INSTALL_DIR" show-ref --verify --quiet "refs/remotes/origin/$REPO_BRANCH"; then
      if ! run_log_only git -C "$INSTALL_DIR" checkout -b "$REPO_BRANCH" "origin/$REPO_BRANCH"; then
        announce_error "Não foi possível criar a branch local '$REPO_BRANCH' a partir de origin."
        exit 1
      fi
    elif [[ "$fetched_origin" == "0" ]]; then
      announce_error "Não foi possível atualizar origin e a branch '$REPO_BRANCH' não existe localmente."
      announce_error "Verifique acesso ao GitHub ou rode uma branch já presente no clone local."
      exit 1
    else
      announce_error "Branch '$REPO_BRANCH' não encontrada no repositório local nem em origin."
      exit 1
    fi

    if [[ "$fetched_origin" == "0" ]]; then
      announce_warning "O 'git pull' será ignorado porque o fetch de origin falhou. O script continuará com a branch local."
      return
    fi

    if ! retry_log_only git -C "$INSTALL_DIR" pull --ff-only origin "$REPO_BRANCH"; then
      announce_warning "Falha ao atualizar '$REPO_BRANCH' com 'git pull --ff-only'. O script continuará com a cópia atual."
    fi
  else
    if [[ -e "$INSTALL_DIR" ]]; then
      announce_error "$INSTALL_DIR já existe e não é um repositório git."
      exit 1
    fi

    announce_step "Clonando repositório..."
    if ! retry_log_only git clone --branch "$REPO_BRANCH" --single-branch "$REPO_HTTPS_URL" "$INSTALL_DIR"; then
      announce_error "Falha ao clonar '$REPO_BRANCH' de $REPO_HTTPS_URL."
      announce_error "Verifique acesso ao GitHub e se a branch existe no remoto."
      exit 1
    fi
  fi
}

run_bootstrap() {
  local bootstrap_system_updated=0
  local forwarded_args=()
  local missing_packages=()

  announce_step "Verificando dependências iniciais já instaladas..."
  collect_missing_packages missing_packages "${BOOTSTRAP_PACKAGES[@]}"
  if ((${#missing_packages[@]} > 0)); then
    announce_step "Instalando dependências iniciais..."
    if ! retry_log_only sudo pacman -Syu --needed --noconfirm "${missing_packages[@]}"; then
      announce_error "Não foi possível instalar as dependências iniciais."
      exit 1
    fi
    bootstrap_system_updated=1
  else
    announce_detail "As dependências iniciais já estão disponíveis. Etapa ignorada."
  fi

  require_command git
  require_command curl
  require_command tar
  sync_repo
  mapfile -t forwarded_args < <(build_bootstrap_args)

  env \
    BOOTSTRAP_DIR="$INSTALL_DIR" \
    POSTINSTALL_LOG_FILE="$LOG_FILE" \
    POSTINSTALL_LOG_INITIALIZED=1 \
    POSTINSTALL_LOCK_HELD=1 \
    POSTINSTALL_SYSTEM_UPDATED="$bootstrap_system_updated" \
    POSTINSTALL_SUMMARY_FILE="$SUMMARY_FILE" \
    POSTINSTALL_STATE_DIR="$STATE_DIR" \
    POSTINSTALL_LOCK_DIR="$LOCK_DIR" \
    SSH_KEY_PATH="$SSH_KEY_PATH" \
    REPOSITORIES_DIR="$REPOSITORIES_DIR" \
    YAY_REPO_DIR="$YAY_REPO_DIR" \
    YAY_SNAPSHOT_URL="$YAY_SNAPSHOT_URL" \
    bash "$INSTALL_DIR/install.sh" "${forwarded_args[@]}"
  exit $?
}

setup_github_ssh() {
  local github_ssh_already_ready=0
  local missing_packages=()

  if ! github_ssh_expected; then
    github_ssh_status="ignorada por configuração"
    announce_detail "A configuração do GitHub SSH foi desativada por opção."
    return
  fi

  announce_detail "Verificando estado atual do GitHub SSH..."
  if has_checkpoint "github_ssh"; then
    announce_detail "Checkpoint do GitHub SSH encontrado. Conferindo autenticação e chave atual..."
    if command -v gh >/dev/null 2>&1 && gh auth status >/dev/null 2>&1 && github_has_expected_ssh_key_title; then
      github_ssh_already_ready=1
    fi
  fi

  if [[ "$github_ssh_already_ready" == "1" ]]; then
    github_ssh_status="ignorada por já estar pronta"
    if ! ensure_repo_origin_remote "$SCRIPT_DIR"; then
      announce_warning "Não foi possível ajustar o remoto do repositório para SSH."
    fi
    announce_detail "O GitHub SSH já está configurado. Etapa ignorada."
    return
  fi

  announce_detail "Registrando dependências da etapa de GitHub SSH..."
  mark_support_package "github-cli"
  mark_support_package "openssh"
  announce_detail "Verificando dependências da etapa de GitHub SSH..."
  collect_missing_packages missing_packages github-cli openssh
  if ((${#missing_packages[@]} > 0)); then
    if ! retry_log_only sudo pacman -S --needed --noconfirm "${missing_packages[@]}"; then
      github_ssh_status="ignorada por falha"
      announce_warning "Não foi possível instalar github-cli/openssh. A configuração do GitHub será ignorada."
      return
    fi
  else
    announce_detail "As dependências do GitHub SSH já estão disponíveis."
  fi

  if ! command -v gh >/dev/null 2>&1 || ! command -v ssh-keygen >/dev/null 2>&1; then
    github_ssh_status="ignorada por falha"
    announce_warning "github-cli ou ssh-keygen está indisponível. A configuração do GitHub será ignorada."
    return
  fi

  if ! ensure_ssh_key; then
    github_ssh_status="ignorada por falha"
    announce_warning "Não foi possível preparar a chave SSH local. A configuração do GitHub será ignorada."
    return
  fi

  if ! ensure_github_auth; then
    cleanup_temp_clipboard_utility || true
    github_ssh_status="ignorada por falha"
    announce_warning "A autenticação do GitHub não foi concluída. O envio da chave SSH será ignorado."
    return
  fi

  if ! upload_ssh_key; then
    cleanup_temp_clipboard_utility || true
    github_ssh_status="ignorada por falha"
    announce_warning "Não foi possível enviar a chave SSH para o GitHub."
    return
  fi

  cleanup_temp_clipboard_utility || true
  if ! mark_checkpoint "github_ssh"; then
    github_ssh_status="ignorada por falha"
    announce_warning "A chave SSH foi configurada, mas o checkpoint do GitHub SSH não pôde ser registrado."
    return
  fi
  github_ssh_status="concluída"
  if ! ensure_repo_origin_remote "$SCRIPT_DIR"; then
    announce_warning "A chave SSH foi configurada, mas não foi possível ajustar o remoto do repositório para SSH."
  fi
}

verify_command() {
  local label="$1"
  local command_name="$2"

  if command -v "$command_name" >/dev/null 2>&1; then
    mark_verified_item "$label"
    return
  fi

  mark_missing_item "$label"
}

verify_package() {
  local label="$1"
  local package_name="$2"

  if pacman -Q "$package_name" >/dev/null 2>&1; then
    mark_verified_item "$label"
    return
  fi

  mark_missing_item "$label"
}

user_service_exists() {
  local service_name="$1"

  systemctl --user cat "$service_name" >/dev/null 2>&1
}

verify_user_service() {
  local label="$1"
  local service_name="$2"

  if ! command -v systemctl >/dev/null 2>&1; then
    mark_missing_item "$label"
    return
  fi

  if ! user_service_exists "$service_name"; then
    mark_missing_item "$label"
    return
  fi

  if systemctl --user --quiet is-active "$service_name"; then
    mark_verified_item "$label"
    return
  fi

  mark_missing_item "$label"
}

start_desktop_user_services() {
  if ! command -v systemctl >/dev/null 2>&1; then
    return 1
  fi

  run_log_only systemctl --user daemon-reload || true
  run_log_only systemctl --user start pipewire.service wireplumber.service xdg-desktop-portal.service
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
  local package_name

  verified_commands=()
  missing_commands=()
  version_info=()

  for package_name in "${packages[@]}"; do
    case "$package_name" in
      codex)
        verify_command "codex" "codex"
        ;;
      nodejs)
        verify_command "nodejs" "node"
        ;;
      *)
        verify_package "$package_name" "$package_name"
        ;;
    esac
  done

  if github_ssh_expected; then
    verify_command "github-cli" "gh"
    verify_command "openssh" "ssh-keygen"
  fi

  if command -v xdg-open >/dev/null 2>&1; then
    mark_verified_item "xdg-utils"
  elif command -v gio >/dev/null 2>&1; then
    mark_verified_item "xdg-utils"
  else
    mark_missing_item "xdg-utils"
  fi

  if command -v wl-copy >/dev/null 2>&1 && command -v wl-paste >/dev/null 2>&1; then
    mark_verified_item "clipboard"
  elif package_is_installed wl-clipboard; then
    mark_missing_item "wl-clipboard"
  fi

  verify_command "pipewire" "pipewire"
  verify_command "wireplumber" "wireplumber"
  verify_package "xdg-desktop-portal" "xdg-desktop-portal"
  verify_package "xdg-desktop-portal-gtk" "xdg-desktop-portal-gtk"
  verify_package "xdg-desktop-portal-hyprland" "xdg-desktop-portal-hyprland"

  verify_user_service "pipewire.service" "pipewire.service"
  verify_user_service "wireplumber.service" "wireplumber.service"
  verify_user_service "xdg-desktop-portal.service" "xdg-desktop-portal.service"

  if [[ \
    " ${verified_commands[*]} " == *" pipewire.service "* && \
    " ${verified_commands[*]} " == *" wireplumber.service "* && \
    " ${verified_commands[*]} " == *" xdg-desktop-portal.service "* \
  ]]; then
    mark_verified_item "screen-sharing-stack"
  else
    mark_missing_item "screen-sharing-stack"
  fi

  collect_version "node" node --version
  collect_version "npm" npm --version
  collect_version "gh" gh --version
  collect_version "codex" codex --version
  collect_version "zen-browser" zen-browser --version
  collect_version "google-chrome-stable" google-chrome-stable --version
}

attempt_final_repair_once() {
  local item
  local repair_pacman_packages=()
  local repair_aur_packages=()
  local pacman_missing_packages=()
  local aur_package
  local package_origin_status
  local should_repair_codex=0
  local should_start_services=0

  if ((${#missing_commands[@]} == 0)); then
    return 0
  fi

  announce_step "Tentando corrigir itens ausentes..."
  for item in "${missing_commands[@]}"; do
    case "$item" in
      codex)
        should_repair_codex=1
        ;;
      github-cli|openssh|xdg-utils|wl-clipboard|pipewire|wireplumber|xdg-desktop-portal|xdg-desktop-portal-gtk|xdg-desktop-portal-hyprland)
        append_array_item repair_pacman_packages "$item"
        ;;
      pipewire.service|wireplumber.service|xdg-desktop-portal.service|screen-sharing-stack)
        should_start_services=1
        ;;
      *)
        if package_exists_in_official_repos "$item"; then
          package_origin_status=0
        else
          package_origin_status=$?
        fi

        if [[ "$package_origin_status" == "0" ]]; then
          append_array_item repair_pacman_packages "$item"
        else
          if [[ "$package_origin_status" == "2" ]]; then
            announce_error "Não foi possível classificar o item ausente '$item' para a correção automática."
            return 1
          fi
          append_array_item repair_aur_packages "$item"
        fi
        ;;
    esac
  done

  collect_missing_packages pacman_missing_packages "${repair_pacman_packages[@]}"
  if ((${#pacman_missing_packages[@]} > 0)); then
    announce_detail "Reinstalando itens via pacman..."
    if ! retry_log_only sudo pacman -S --needed --noconfirm "${pacman_missing_packages[@]}"; then
      return 1
    fi
  fi

  if ((${#repair_aur_packages[@]} > 0)); then
    if ! ensure_aur_helper; then
      return 1
    fi

    for aur_package in "${repair_aur_packages[@]}"; do
      if package_is_installed "$aur_package"; then
        continue
      fi

      announce_detail "Reinstalando item via AUR: $aur_package"
      if ! retry_log_only "$aur_helper" -S --needed --noconfirm "$aur_package"; then
        return 1
      fi
    done
  fi

  if (( should_repair_codex == 1 )); then
    announce_detail "Reconfigurando o Codex CLI..."
    if ! setup_codex_cli; then
      return 1
    fi
  fi

  if (( should_start_services == 1 )) || ((${#pacman_missing_packages[@]} > 0)); then
    announce_detail "Tentando iniciar os serviços de usuário necessários..."
    start_desktop_user_services || true
  fi

  if desktop_integration_ready && ! has_checkpoint "desktop_integration" && ! mark_checkpoint "desktop_integration"; then
    announce_warning "Não foi possível registrar o checkpoint da integração desktop após a correção automática."
  fi

  verify_installation
  ((${#missing_commands[@]} == 0))
}

ensure_final_verification_passed() {
  if ((${#missing_commands[@]} == 0)); then
    return 0
  fi

  if attempt_final_repair_once; then
    return 0
  fi

  announce_error "A verificação final encontrou itens ausentes após a instalação."
  announce_error "Itens ausentes: ${missing_commands[*]}"
  return 1
}

run_install() {
  official_packages=()
  aur_packages=()
  official_failed=()
  aur_failed=()
  support_packages=()
  environment_packages=()
  aur_helper_status="não preparado"
  github_ssh_status="pendente"
  desktop_integration_status="pendente"
  announce_step "Carregando configuração..."
  load_packages
  if [[ "$CHECK_ONLY" == "1" ]]; then
    announce_step "Executando verificação sem alterações..."
    detect_aur_helper || true
    if desktop_integration_ready; then
      desktop_integration_status="ignorada por já estar pronta"
    else
      desktop_integration_status="pendente"
    fi
    for package_name in \
      pipewire \
      wireplumber \
      xdg-utils \
      xdg-desktop-portal \
      xdg-desktop-portal-gtk \
      xdg-desktop-portal-hyprland; do
      mark_environment_package "$package_name"
    done
    if github_ssh_expected; then
      if github_ssh_ready; then
        github_ssh_status="ignorada por já estar pronta"
      else
        github_ssh_status="pendente"
      fi
    else
      github_ssh_status="ignorada por configuração"
    fi
    verify_installation
    print_summary
    if ((${#missing_commands[@]} > 0)); then
      announce_error "A verificação sem alterações encontrou itens ausentes."
      exit 1
    fi
    return 0
  fi

  create_directories
  ensure_multilib

  if [[ "$SYSTEM_UPDATED" == "1" ]]; then
    announce_detail "O sistema já foi atualizado no bootstrap. A nova atualização completa será ignorada."
  else
    announce_step "Atualizando o sistema..."
    if ! retry_log_only sudo pacman -Syu --noconfirm; then
      announce_error "Não foi possível concluir a atualização completa do sistema."
      print_summary
      exit 1
    fi
  fi

  announce_step "Preparando helper AUR..."
  if ! ensure_aur_helper; then
    announce_error "Não foi possível preparar o helper AUR padrão para a instalação."
    print_summary
    exit 1
  fi

  if ! install_packages_in_order; then
    print_summary
    exit 1
  fi

  if ((${#official_failed[@]} > 0 || ${#aur_failed[@]} > 0)); then
    print_summary
    exit 1
  fi
  announce_step "Ajustando integração desktop..."
  if ! ensure_desktop_integration; then
    announce_error "A integração desktop falhou. A etapa do GitHub SSH não foi executada."
    print_summary
    exit 1
  fi
  announce_step "Configurando GitHub SSH..."
  setup_github_ssh
  announce_step "Validando instalação..."
  verify_installation
  if ! ensure_final_verification_passed; then
    print_summary
    exit 1
  fi
  print_summary
}

main() {
  parse_cli_args "$@"
  trap cleanup EXIT
  ensure_not_root
  acquire_lock
  init_logging
  if [[ -f "$PACKAGE_FILE" ]]; then
    if [[ "$CHECK_ONLY" == "1" ]]; then
      set_step_total 3
    else
      set_step_total 11
    fi
  else
    local bootstrap_missing_packages=()
    collect_missing_packages bootstrap_missing_packages "${BOOTSTRAP_PACKAGES[@]}"
    if ((${#bootstrap_missing_packages[@]} > 0)); then
      set_step_total 4
    else
      set_step_total 3
    fi
  fi
  announce_step "Validando ambiente..."
  ensure_arch
  ensure_supported_session
  require_command pacman
  require_command sudo
  announce_prompt "Autenticando sudo..."
  sudo -v

  if [[ -f "$PACKAGE_FILE" ]]; then
    run_install
  else
    run_bootstrap
  fi
}

main "$@"
