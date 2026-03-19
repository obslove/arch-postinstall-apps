#!/usr/bin/env bash
# shellcheck shell=bash

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

package_is_installed() {
  pacman -Q "$1" >/dev/null 2>&1
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

retry() {
  "$@"
}

retry_log_only() {
  run_log_only "$@"
}

retry_interactive_log_only() {
  run_interactive_log_only "$@"
}
