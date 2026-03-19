#!/usr/bin/env bash
# shellcheck shell=bash
# shellcheck disable=SC2034
# shellcheck source-path=SCRIPTDIR
# shellcheck source=scripts/lib/runtime-state.sh

if false; then
  source "$SCRIPT_DIR/scripts/lib/runtime-state.sh"
fi

init_output_styles() {
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
}

step_result_reset() {
  STEP_RESULT_STATUS=""
  STEP_RESULT_MESSAGE=""
  STEP_RESULT_SUMMARY_PRINTED=0
}

step_result_success() {
  STEP_RESULT_STATUS="success"
  STEP_RESULT_MESSAGE="${1:-}"
}

step_result_skipped() {
  STEP_RESULT_STATUS="skipped"
  STEP_RESULT_MESSAGE="${1:-}"
}

step_result_soft_fail() {
  STEP_RESULT_STATUS="soft_fail"
  STEP_RESULT_MESSAGE="${1:-}"
}

step_result_hard_fail() {
  STEP_RESULT_STATUS="hard_fail"
  STEP_RESULT_MESSAGE="${1:-}"
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
  state_add_support_package "$1"
}

mark_environment_package() {
  state_add_environment_package "$1"
}

mark_verified_item() {
  state_add_verified_item "$1"
}

mark_missing_item() {
  state_add_missing_item "$1"
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
