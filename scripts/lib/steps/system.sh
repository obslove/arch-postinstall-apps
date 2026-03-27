#!/usr/bin/env bash
# shellcheck shell=bash
# shellcheck disable=SC2034
# shellcheck source-path=SCRIPTDIR
# shellcheck source=scripts/lib/status.sh
# shellcheck source=scripts/lib/runtime-state.sh
# shellcheck source=scripts/lib/step-manifest.sh

runtime_validate_environment_step() {
  step_result_reset

  if ! ensure_arch; then
    step_result_hard_fail "Este instalador só pode ser executado em Arch Linux."
    return 0
  fi

  if ! ensure_supported_session; then
    step_result_hard_fail "A sessão atual não é compatível com o instalador."
    return 0
  fi

  if ! require_command pacman; then
    step_result_hard_fail "O comando 'pacman' é obrigatório para continuar."
    return 0
  fi

  if ! require_command sudo; then
    step_result_hard_fail "O comando 'sudo' é obrigatório para continuar."
    return 0
  fi

  announce_prompt "Autenticando sudo..."
  if ! ops_sudo_auth; then
    step_result_hard_fail "Não foi possível autenticar o sudo."
    return 0
  fi

  init_logging
  step_result_success "O ambiente foi validado."
}

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

load_configuration_step() {
  local array_name="$1"

  step_result_reset
  if ! load_packages "$array_name"; then
    step_result_hard_fail "Não foi possível carregar a configuração de pacotes."
    return 0
  fi

  if ! report_requested_main_packages "$array_name"; then
    step_result_hard_fail "Não foi possível classificar a lista principal de pacotes."
    return 0
  fi

  if [[ "$CHECK_ONLY" != "1" ]]; then
    if ! append_runtime_install_pipeline "$array_name"; then
      step_result_hard_fail "Não foi possível montar o pipeline de instalação."
      return 0
    fi
    set_step_total "$(pipeline_count_steps_for_mode install)"
  fi

  step_result_success "A configuração de pacotes foi carregada."
}

check_only_step() {
  local array_name="$1"
  local detection_component_ids=()
  local component_id
  local package_name

  step_result_reset
  mapfile -t detection_component_ids < <(component_check_only_detection_ids)
  for component_id in "${detection_component_ids[@]}"; do
    component_prepare_check_only_state "$component_id" || true
  done
  for package_name in "${LOCAL_SUPPORT_PACKAGES[@]}"; do
    report_add_requested_support_package "$package_name"
  done
  for package_name in "${DESKTOP_INTEGRATION_PACKAGES[@]}"; do
    report_add_requested_environment_package "$package_name"
  done
  verify_installation "$array_name"
  print_summary
  STEP_RESULT_SUMMARY_PRINTED=1
  if state_has_missing_items; then
    step_result_hard_fail "A verificação sem alterações encontrou itens ausentes."
    return 0
  fi

  step_result_success "A verificação sem alterações foi concluída."
}

create_directories_step() {
  step_result_reset

  if ! create_directories; then
    step_result_hard_fail "Não foi possível criar os diretórios base do ambiente."
    return 0
  fi

  step_result_success "Os diretórios base foram garantidos."
}

relocate_home_repositories_step() {
  local loose_repositories=()
  local repo_dir
  local move_status=0
  local moved_count=0
  local failed_count=0

  step_result_reset

  collect_loose_home_git_repositories loose_repositories
  if ((${#loose_repositories[@]} == 0)); then
    step_result_skipped "Nenhum repositório git solto foi encontrado na home."
    return 0
  fi

  for repo_dir in "${loose_repositories[@]}"; do
    relocate_loose_home_git_repository "$repo_dir"
    move_status=$?

    case "$move_status" in
      0)
        moved_count=$((moved_count + 1))
        report_mark_change "home_repo:$(basename "$repo_dir")"
        ;;
      2)
        ;;
      *)
        failed_count=$((failed_count + 1))
        ;;
    esac
  done

  if (( failed_count > 0 )); then
    step_result_soft_fail "Nem todos os repositórios git soltos na home puderam ser movidos para $REPOSITORIES_DIR."
    return 0
  fi

  if (( moved_count > 0 )); then
    step_result_success "Os repositórios git soltos na home foram movidos para $REPOSITORIES_DIR."
    return 0
  fi

  step_result_skipped "Os repositórios git soltos já estavam alinhados com $REPOSITORIES_DIR."
}

sync_managed_repositories_step() {
  local repo_sync_handlers=(
    "sync_easyeffects_preset_repo"
    "sync_terminal_lyrics_repo"
    "sync_synthetic_profile_generator_repo"
    "sync_obslove_dots_repo"
  )
  local sync_handler=""
  local sync_status=0
  local changed_count=0
  local failed_count=0
  local skipped_count=0

  step_result_reset

  for sync_handler in "${repo_sync_handlers[@]}"; do
    "$sync_handler"
    sync_status=$?

    case "$sync_status" in
      0)
        changed_count=$((changed_count + 1))
        ;;
      2|3)
        skipped_count=$((skipped_count + 1))
        ;;
      *)
        failed_count=$((failed_count + 1))
        ;;
    esac
  done

  if (( changed_count > 0 )); then
    report_mark_change "managed_repositories"
  fi

  if (( failed_count > 0 )); then
    step_result_soft_fail "Nem todos os repositórios gerenciados puderam ser sincronizados."
    return 0
  fi

  if (( changed_count > 0 )); then
    step_result_success "Os repositórios gerenciados foram garantidos em Projects, Dots e EasyEffects-Preset."
    return 0
  fi

  if (( skipped_count > 0 )); then
    step_result_skipped "Os repositórios gerenciados já estavam alinhados ou foram mantidos como estão."
    return 0
  fi

  step_result_skipped "Nenhum repositório gerenciado precisou de sincronização."
}

ensure_multilib_step() {
  step_result_reset

  if ! ensure_multilib; then
    step_result_hard_fail "Não foi possível preparar o repositório multilib."
    return 0
  fi

  step_result_success "O repositório multilib foi preparado."
}
