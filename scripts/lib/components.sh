#!/usr/bin/env bash
# shellcheck shell=bash

component_dispatch() {
  local action="$1"
  local component_id="$2"
  local handler_name=""

  shift 2
  handler_name="$(component_action_handler "$action" "$component_id" 2>/dev/null || true)"

  if [[ -z "$handler_name" ]]; then
    announce_error "Componente '$component_id' não registra a ação '$action'."
    return 1
  fi

  if ! declare -F "$handler_name" >/dev/null 2>&1; then
    announce_error "Componente '$component_id' não implementa a ação '$action'."
    return 1
  fi

  "$handler_name" "$@"
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

component_summary_status_text() {
  local component_id="$1"
  local summary_formatter=""
  local component_outcome=""

  summary_formatter="$(component_summary_formatter_function "$component_id" 2>/dev/null || true)"
  [[ -n "$summary_formatter" ]] || return 1

  if component_has_runtime_status "$component_id"; then
    component_outcome="$(report_get_component_outcome "$component_id")"
    "$summary_formatter" "$component_outcome"
    return 0
  fi

  "$summary_formatter"
}

component_prepare_check_only_state() {
  local component_id="$1"

  if ! component_is_expected "$component_id"; then
    if component_has_runtime_status "$component_id"; then
      report_set_component_outcome "$component_id" "$COMPONENT_OUTCOME_DISABLED"
    fi
    return 0
  fi

  if component_detect "$component_id"; then
    if component_has_runtime_status "$component_id"; then
      report_set_component_outcome "$component_id" "$COMPONENT_OUTCOME_REUSED"
    fi
    return 0
  fi

  if component_has_runtime_status "$component_id"; then
    report_set_component_outcome "$component_id" "$COMPONENT_OUTCOME_PENDING"
  fi
}
