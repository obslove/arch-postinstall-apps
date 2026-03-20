#!/usr/bin/env bash
# shellcheck shell=bash

github_ssh_step() {
  local github_status=""

  step_result_reset
  component_apply github_ssh
  github_status="$(state_get_component_status github_ssh)"

  case "$github_status" in
    "$STATUS_DONE")
      step_result_success "O GitHub SSH foi configurado."
      ;;
    "$STATUS_SKIPPED_DISABLED")
      step_result_skipped "A configuração do GitHub SSH foi desativada por opção."
      ;;
    "$STATUS_SKIPPED_READY")
      step_result_skipped "O GitHub SSH já estava configurado."
      ;;
    "$STATUS_SKIPPED_DECLINED")
      step_result_skipped "A remoção exclusiva de chaves SSH do GitHub foi cancelada."
      ;;
    "$STATUS_SOFT_FAILED")
      step_result_soft_fail "A configuração do GitHub SSH foi ignorada após uma falha."
      ;;
    *)
      step_result_soft_fail "A configuração do GitHub SSH terminou com estado inesperado: $github_status"
      ;;
  esac
}

pipeline_github_ssh_step() {
  announce_step "Configurando GitHub SSH..."
  github_ssh_step
  handle_runtime_step_result_or_exit
}
