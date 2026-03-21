#!/usr/bin/env bash
# shellcheck shell=bash

github_ssh_step() {
  local github_outcome=""
  local step_status=""

  step_result_reset
  component_apply github_ssh
  github_outcome="$(report_get_component_outcome "github_ssh")"
  step_status="$(component_outcome_step_status "$github_outcome" 2>/dev/null || true)"

  case "$github_outcome" in
    "$COMPONENT_OUTCOME_CHANGED")
      step_result_success "O GitHub SSH foi configurado."
      ;;
    "$COMPONENT_OUTCOME_DISABLED")
      step_result_skipped "A configuração do GitHub SSH foi desativada por opção."
      ;;
    "$COMPONENT_OUTCOME_REUSED")
      step_result_skipped "O GitHub SSH já estava configurado."
      ;;
    "$COMPONENT_OUTCOME_DECLINED")
      step_result_skipped "A remoção exclusiva de chaves SSH do GitHub foi cancelada."
      ;;
    "$COMPONENT_OUTCOME_SOFT_FAILED")
      step_result_soft_fail "A configuração do GitHub SSH foi ignorada após uma falha."
      ;;
    "$COMPONENT_OUTCOME_FAILED")
      step_result_hard_fail "A configuração do GitHub SSH falhou."
      ;;
    *)
      case "$step_status" in
        skipped)
          step_result_skipped "A configuração do GitHub SSH foi ignorada."
          ;;
        soft_fail)
          step_result_soft_fail "A configuração do GitHub SSH terminou com estado inesperado: $github_outcome"
          ;;
        hard_fail)
          step_result_hard_fail "A configuração do GitHub SSH terminou com estado inesperado: $github_outcome"
          ;;
        *)
          step_result_soft_fail "A configuração do GitHub SSH terminou com estado inesperado: $github_outcome"
          ;;
      esac
      ;;
  esac
}
