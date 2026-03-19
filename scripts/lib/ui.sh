#!/usr/bin/env bash
# shellcheck shell=bash
# shellcheck disable=SC2034

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
