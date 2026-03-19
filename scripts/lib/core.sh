#!/usr/bin/env bash

config_init() {
  local repo_dir="$1"

  REPO_DIR="$repo_dir"
  SCRIPT_DIR="$REPO_DIR"
  PACKAGE_FILE="$REPO_DIR/config/packages.txt"
  EXTRA_PACKAGE_FILE="$REPO_DIR/config/packages-extra.txt"
  BASHRC_FILE="$HOME/.bashrc"
  ZSHRC_FILE="$HOME/.zshrc"
  FISH_CONFIG_FILE="$HOME/.config/fish/config.fish"
  REPO_HTTPS_URL="https://github.com/obslove/arch-postinstall-apps.git"
  REPO_SSH_URL="git@github.com:obslove/arch-postinstall-apps.git"
  REPOSITORIES_DIR="${REPOSITORIES_DIR:-$HOME/Repositories}"
  INSTALL_DIR="${BOOTSTRAP_DIR:-$REPOSITORIES_DIR/arch-postinstall-apps}"
  YAY_REPO_DIR="${YAY_REPO_DIR:-$REPOSITORIES_DIR/yay}"
  YAY_SNAPSHOT_URL="${YAY_SNAPSHOT_URL:-https://aur.archlinux.org/cgit/aur.git/snapshot/yay.tar.gz}"
  SSH_KEY_PATH="${SSH_KEY_PATH:-$HOME/.ssh/id_ed25519}"
  GITHUB_SSH_KEY_NAME=""
  LOG_FILE="${POSTINSTALL_LOG_FILE:-$HOME/Backups/arch-postinstall.log}"
  SUMMARY_FILE="${POSTINSTALL_SUMMARY_FILE:-$HOME/Backups/arch-postinstall-summary.txt}"
  CHECK_ONLY=0
  EXCLUSIVE_GITHUB_SSH_KEY=0
  SKIP_GITHUB_SSH=0
  STEP_OUTPUT_ONLY=1
  STATE_DIR="${POSTINSTALL_STATE_DIR:-${XDG_STATE_HOME:-$HOME/.local/state}/arch-postinstall-apps}"
  LOCK_DIR="${POSTINSTALL_LOCK_DIR:-$STATE_DIR/lock}"
  LOCK_HELD="${POSTINSTALL_LOCK_HELD:-0}"
  SYSTEM_UPDATED="${POSTINSTALL_BOOTSTRAP_UPDATED:-${POSTINSTALL_SYSTEM_UPDATED:-0}}"
}

finalize_config() {
  readonly REPO_DIR
  readonly SCRIPT_DIR
  readonly PACKAGE_FILE
  readonly EXTRA_PACKAGE_FILE
  readonly BASHRC_FILE
  readonly ZSHRC_FILE
  readonly FISH_CONFIG_FILE
  readonly REPO_HTTPS_URL
  readonly REPO_SSH_URL
  readonly REPOSITORIES_DIR
  readonly INSTALL_DIR
  readonly YAY_REPO_DIR
  readonly YAY_SNAPSHOT_URL
  readonly SSH_KEY_PATH
  readonly GITHUB_SSH_KEY_NAME
  readonly LOG_FILE
  readonly SUMMARY_FILE
  readonly CHECK_ONLY
  readonly EXCLUSIVE_GITHUB_SSH_KEY
  readonly SKIP_GITHUB_SSH
  readonly STEP_OUTPUT_ONLY
  readonly STATE_DIR
  readonly LOCK_DIR
  readonly SYSTEM_UPDATED
}

execution_state_reset() {
  official_packages=()
  aur_packages=()
  official_failed=()
  aur_failed=()
  support_packages=()
  environment_packages=()
  aur_helper=""
  aur_helper_status="não preparado"
  verified_commands=()
  missing_commands=()
  version_info=()
  temp_clipboard_package=""
  official_repo_metadata_checked=0
  official_repo_metadata_ready=0
  github_ssh_status="pendente"
  desktop_integration_status="pendente"
}

runtime_state_init() {
  cleanup_paths=()
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

  execution_state_reset
}

print_usage() {
  cat <<'EOF'
Uso:
  bash install.sh [opções]
  curl -fsSL https://obslove.dev | bash -s -- [opções]

Opções:
  -c, --check             Valida o ambiente sem instalar nem alterar o sistema.
  -e, --exclusive-key     Destrutiva: remove as outras chaves SSH do GitHub e mantém só a atual.
  -n, --no-gh             Pula a etapa de GitHub SSH.
  -s, --ssh-name NOME     Define o nome da chave SSH enviada ao GitHub.
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
      -e|--exclusive-key)
        EXCLUSIVE_GITHUB_SSH_KEY=1
        shift
        ;;
      -n|--no-gh)
        SKIP_GITHUB_SSH=1
        shift
        ;;
      -s|--ssh-name)
        [[ $# -ge 2 ]] || {
          printf 'Erro: faltou informar o valor de %s.\n' "$1" >&2
          exit 1
        }
        GITHUB_SSH_KEY_NAME="$2"
        shift 2
        ;;
      --ssh-name=*)
        GITHUB_SSH_KEY_NAME="${1#*=}"
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
    LOCK_HELD=1
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
      LOCK_HELD=1
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

github_ssh_force_reconcile() {
  [[ "$EXCLUSIVE_GITHUB_SSH_KEY" == "1" || -n "$GITHUB_SSH_KEY_NAME" ]]
}

run_with_terminal_stdin() {
  if [[ -r /dev/tty ]]; then
    "$@" </dev/tty
    return
  fi

  "$@"
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

write_log_only() {
  if [[ "${POSTINSTALL_LOG_INITIALIZED:-0}" != "1" ]]; then
    return 0
  fi

  printf '%s\n' "$1" >>"$LOG_FILE"
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
    if [[ "$1" == *"Etapa ignorada."* || "$1" == Instalando\ via\ pacman:* || "$1" == Instalando\ via\ AUR:* ]]; then
      write_log_only "$1"
      return 0
    fi
    printf '│  %s %s\n' "$(style_text "$style_detail" "•")" "$1"
    return 0
  fi

  printf '│  %s %s\n' "$(style_text "$style_detail" "•")" "$1"
}

announce_warning() {
  emit_notice "!" "$style_warning" "$1"
}

announce_error() {
  emit_notice "x" "$style_error" "$1"
}

announce_prompt() {
  emit_notice "?" "$style_step" "$1"
}

run_log_only() {
  if [[ "$STEP_OUTPUT_ONLY" == "1" ]]; then
    "$@" </dev/null >>"$LOG_FILE" 2>&1
    return
  fi

  "$@" </dev/null 2>&1 | sed 's/^/│    /'
  return "${PIPESTATUS[0]}"
}

run_interactive_log_only() {
  if [[ "$STEP_OUTPUT_ONLY" == "1" ]]; then
    run_with_terminal_stdin "$@" >>"$LOG_FILE" 2>&1
    return
  fi

  run_with_terminal_stdin "$@" 2>&1 | sed 's/^/│    /'
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
  "$@"
}

retry_log_only() {
  run_log_only "$@"
}

retry_interactive_log_only() {
  run_interactive_log_only "$@"
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

ensure_arch() {
  if [[ ! -f /etc/arch-release ]]; then
    announce_error "Este script foi feito para Arch Linux."
    exit 1
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
