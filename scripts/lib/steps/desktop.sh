#!/usr/bin/env bash
# shellcheck shell=bash

desktop_integration_step() {
  local desktop_status=""

  step_result_reset

  if component_apply desktop_integration; then
    desktop_status="$(state_get_component_status desktop_integration)"
    case "$desktop_status" in
      "$STATUS_SKIPPED_READY")
        step_result_skipped "A integração desktop já estava pronta."
        ;;
      *)
        step_result_success "A integração desktop foi concluída."
        ;;
    esac
    return 0
  fi

  step_result_hard_fail "A integração desktop falhou. A etapa do GitHub SSH não foi executada."
}
