#!/usr/bin/env bash
# shellcheck shell=bash

component_function_name() {
  local action="$1"
  local component_id="$2"

  printf 'component_%s_%s\n' "$action" "$component_id"
}

component_dispatch() {
  local action="$1"
  local component_id="$2"
  local function_name

  shift 2
  function_name="$(component_function_name "$action" "$component_id")"

  if ! declare -F "$function_name" >/dev/null 2>&1; then
    announce_error "Componente '$component_id' não implementa a ação '$action'."
    return 1
  fi

  "$function_name" "$@"
}

component_detect() {
  component_dispatch detect "$@"
}

component_apply() {
  component_dispatch apply "$@"
}

component_verify() {
  component_dispatch verify "$@"
}

component_checkpoint_key() {
  component_dispatch checkpoint_key "$@"
}

component_has_checkpoint() {
  local component_id="$1"
  local checkpoint_key=""

  checkpoint_key="$(component_checkpoint_key "$component_id" 2>/dev/null || true)"
  [[ -n "$checkpoint_key" ]] || return 1
  has_checkpoint "$checkpoint_key"
}

component_mark_checkpoint_if_missing() {
  local component_id="$1"
  local checkpoint_key=""

  checkpoint_key="$(component_checkpoint_key "$component_id" 2>/dev/null || true)"
  [[ -n "$checkpoint_key" ]] || return 0

  if ! has_checkpoint "$checkpoint_key"; then
    mark_checkpoint "$checkpoint_key"
  fi
}

component_summary_status_text() {
  local component_id="$1"
  local summary_formatter=""

  summary_formatter="$(component_summary_formatter_function "$component_id" 2>/dev/null || true)"
  [[ -n "$summary_formatter" ]] || return 1

  if component_has_runtime_status "$component_id"; then
    "$summary_formatter" "$(state_get_component_status "$component_id")"
    return 0
  fi

  "$summary_formatter"
}

component_prepare_check_only_state() {
  local component_id="$1"

  if ! component_is_expected "$component_id"; then
    if component_has_runtime_status "$component_id"; then
      state_set_component_status "$component_id" "$STATUS_SKIPPED_DISABLED"
    fi
    return 0
  fi

  if component_detect "$component_id"; then
    if component_has_runtime_status "$component_id"; then
      state_set_component_status "$component_id" "$STATUS_SKIPPED_READY"
    fi
    return 0
  fi

  if component_has_runtime_status "$component_id"; then
    state_set_component_status "$component_id" "$STATUS_PENDING"
  fi
}
