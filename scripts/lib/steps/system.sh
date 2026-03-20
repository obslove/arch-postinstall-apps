#!/usr/bin/env bash
# shellcheck shell=bash
# shellcheck disable=SC2034
# shellcheck source-path=SCRIPTDIR
# shellcheck source=scripts/lib/shellcheck-runtime.sh
# shellcheck source=scripts/lib/status.sh
# shellcheck source=scripts/lib/runtime-state.sh

if false; then
  source "$SCRIPT_DIR/scripts/lib/shellcheck-runtime.sh"
  source "$SCRIPT_DIR/scripts/lib/status.sh"
  source "$SCRIPT_DIR/scripts/lib/runtime-state.sh"
fi

update_system_step() {
  step_result_reset

  if [[ "$SYSTEM_UPDATED" == "1" ]]; then
    announce_detail "O sistema já foi atualizado no bootstrap. A nova atualização completa será ignorada."
    step_result_skipped "A atualização completa do sistema foi ignorada porque já ocorreu no bootstrap."
    return 0
  fi

  if ops_pacman_upgrade_full; then
    step_result_success "A atualização completa do sistema foi concluída."
    return 0
  fi

  step_result_hard_fail "Não foi possível concluir a atualização completa do sistema."
}

pipeline_load_configuration_step() {
  local array_name="$1"

  step_result_reset
  announce_step "Carregando configuração..."
  if ! load_packages "$array_name"; then
    step_result_hard_fail "Não foi possível carregar a configuração de pacotes."
    handle_runtime_step_result_or_exit
    return 0
  fi

  if [[ "$CHECK_ONLY" != "1" ]]; then
    set_step_total "$(calculate_install_step_total "$array_name")"
  fi

  step_result_success "A configuração de pacotes foi carregada."
}

pipeline_check_only_step() {
  local array_name="$1"
  local detection_component_ids=()
  local component_id
  local package_name

  step_result_reset
  announce_step "Executando verificação sem alterações..."
  mapfile -t detection_component_ids < <(component_check_only_detection_ids)
  for component_id in "${detection_component_ids[@]}"; do
    component_prepare_check_only_state "$component_id" || true
  done
  for package_name in "${DESKTOP_INTEGRATION_PACKAGES[@]}"; do
    state_add_environment_package "$package_name"
  done
  verify_installation "$array_name"
  print_summary
  STEP_RESULT_SUMMARY_PRINTED=1
  if state_has_missing_items; then
    step_result_hard_fail "A verificação sem alterações encontrou itens ausentes."
    handle_runtime_step_result_or_exit
    return 0
  fi

  step_result_success "A verificação sem alterações foi concluída."
}

pipeline_create_directories_step() {
  create_directories
}

pipeline_ensure_multilib_step() {
  step_result_reset

  if ! ensure_multilib; then
    step_result_hard_fail "Não foi possível preparar o repositório multilib."
    handle_runtime_step_result_or_exit
    return 0
  fi

  step_result_success "O repositório multilib foi preparado."
}

pipeline_update_system_step() {
  announce_step "Atualizando o sistema..."
  update_system_step
  handle_runtime_step_result_or_exit
}
