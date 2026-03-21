#!/usr/bin/env bash
# shellcheck shell=bash

desktop_integration_step() {
  local desktop_outcome=""
  local step_status=""

  step_result_reset

  if component_apply desktop_integration; then
    desktop_outcome="$(report_get_component_outcome "desktop_integration")"
    step_status="$(component_outcome_step_status "$desktop_outcome")"
    case "$step_status" in
      skipped)
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
