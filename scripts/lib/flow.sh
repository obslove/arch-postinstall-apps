#!/usr/bin/env bash
# shellcheck shell=bash
# shellcheck source-path=SCRIPTDIR
# shellcheck source=scripts/lib/shellcheck-runtime.sh
# shellcheck source=scripts/lib/ops.sh
# shellcheck source=scripts/lib/summary.sh
# shellcheck source=scripts/lib/pipeline.sh

if false; then
  source "$SCRIPT_DIR/scripts/lib/shellcheck-runtime.sh"
  source "$SCRIPT_DIR/scripts/lib/ops.sh"
  source "$SCRIPT_DIR/scripts/lib/summary.sh"
  source "$SCRIPT_DIR/scripts/lib/pipeline.sh"
fi

handle_runtime_step_result_or_exit() {
  case "${STEP_RESULT_STATUS:-}" in
    success|"")
      return 0
      ;;
    skipped)
      return 0
      ;;
    soft_fail)
      record_soft_failure "$STEP_RESULT_MESSAGE"
      return 0
      ;;
    hard_fail)
      if [[ -n "${STEP_RESULT_MESSAGE:-}" ]]; then
        announce_error "$STEP_RESULT_MESSAGE"
      fi
      print_summary
      exit 1
      ;;
    *)
      announce_error "Resultado de etapa desconhecido: ${STEP_RESULT_STATUS:-indefinido}"
      print_summary
      exit 1
      ;;
  esac
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

prepare_aur_helper_step() {
  step_result_reset

  if ensure_aur_helper; then
    step_result_success "O helper AUR foi preparado."
    return 0
  fi

  step_result_hard_fail "Não foi possível preparar o helper AUR padrão para a instalação."
}

install_packages_step() {
  local array_name="$1"

  step_result_reset

  if ! install_packages_in_order "$array_name"; then
    step_result_hard_fail "Falha ao executar a instalação dos pacotes configurados."
    return 0
  fi

  if ((${#official_failed[@]} > 0 || ${#aur_failed[@]} > 0)); then
    step_result_hard_fail "A instalação terminou com falhas em pacotes configurados."
    return 0
  fi

  step_result_success "Os pacotes configurados foram tratados."
}

desktop_integration_step() {
  step_result_reset

  if ensure_desktop_integration; then
    case "$desktop_integration_status" in
      "ignorada por já estar pronta")
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

github_ssh_step() {
  step_result_reset
  setup_github_ssh

  case "$github_ssh_status" in
    "concluída")
      step_result_success "O GitHub SSH foi configurado."
      ;;
    "ignorada por configuração")
      step_result_skipped "A configuração do GitHub SSH foi desativada por opção."
      ;;
    "ignorada por já estar pronta")
      step_result_skipped "O GitHub SSH já estava configurado."
      ;;
    "ignorada por confirmação negada")
      step_result_skipped "A remoção exclusiva de chaves SSH do GitHub foi cancelada."
      ;;
    "ignorada por falha")
      step_result_soft_fail "A configuração do GitHub SSH foi ignorada após uma falha."
      ;;
    *)
      step_result_soft_fail "A configuração do GitHub SSH terminou com estado inesperado: $github_ssh_status"
      ;;
  esac
}

final_verification_step() {
  local array_name="$1"

  step_result_reset
  verify_installation "$array_name"

  if ensure_final_verification_passed "$array_name"; then
    step_result_success "A verificação final foi concluída."
    return 0
  fi

  step_result_hard_fail "A verificação final encontrou itens ausentes após a instalação."
}

pipeline_load_configuration_step() {
  local array_name="$1"

  announce_step "Carregando configuração..."
  load_packages "$array_name"
  if [[ "$CHECK_ONLY" != "1" ]]; then
    set_step_total "$(calculate_install_step_total "$array_name")"
  fi
}

pipeline_check_only_step() {
  local array_name="$1"
  local package_name

  announce_step "Executando verificação sem alterações..."
  detect_aur_helper || true
  if desktop_integration_ready; then
    desktop_integration_status="ignorada por já estar pronta"
  else
    desktop_integration_status="pendente"
  fi
  for package_name in "${DESKTOP_INTEGRATION_PACKAGES[@]}"; do
    mark_environment_package "$package_name"
  done
  if github_ssh_expected; then
    if github_ssh_ready; then
      github_ssh_status="ignorada por já estar pronta"
    else
      github_ssh_status="pendente"
    fi
  else
    github_ssh_status="ignorada por configuração"
  fi
  verify_installation "$array_name"
  print_summary
  if ((${#missing_commands[@]} > 0)); then
    announce_error "A verificação sem alterações encontrou itens ausentes."
    exit 1
  fi
}

pipeline_create_directories_step() {
  create_directories
}

pipeline_ensure_multilib_step() {
  ensure_multilib
}

pipeline_update_system_step() {
  announce_step "Atualizando o sistema..."
  update_system_step
  handle_runtime_step_result_or_exit
}

pipeline_prepare_aur_helper_step() {
  announce_step "Preparando helper AUR..."
  prepare_aur_helper_step
  handle_runtime_step_result_or_exit
}

pipeline_install_packages_step() {
  local array_name="$1"

  install_packages_step "$array_name"
  handle_runtime_step_result_or_exit
}

pipeline_desktop_integration_step() {
  announce_step "Ajustando integração desktop..."
  desktop_integration_step
  handle_runtime_step_result_or_exit
}

pipeline_github_ssh_step() {
  announce_step "Configurando GitHub SSH..."
  github_ssh_step
  handle_runtime_step_result_or_exit
}

pipeline_final_verification_step() {
  local array_name="$1"

  announce_step "Validando instalação..."
  final_verification_step "$array_name"
  handle_runtime_step_result_or_exit
}

define_runtime_pipeline() {
  local array_name="$1"

  pipeline_reset
  pipeline_add_step "load_configuration" "all" "pipeline_load_configuration_step" "$array_name"

  if [[ "$CHECK_ONLY" == "1" ]]; then
    pipeline_add_step "check_only_verification" "check" "pipeline_check_only_step" "$array_name"
    return 0
  fi

  pipeline_add_step "create_directories" "install" "pipeline_create_directories_step"
  pipeline_add_step "ensure_multilib" "install" "pipeline_ensure_multilib_step"
  pipeline_add_step "update_system" "install" "pipeline_update_system_step"
  pipeline_add_step "prepare_aur_helper" "install" "pipeline_prepare_aur_helper_step"
  pipeline_add_step "install_packages" "install" "pipeline_install_packages_step" "$array_name"
  pipeline_add_step "desktop_integration" "install" "pipeline_desktop_integration_step"
  pipeline_add_step "github_ssh" "install" "pipeline_github_ssh_step"
  pipeline_add_step "final_verification" "install" "pipeline_final_verification_step" "$array_name"
}

run_install() {
  local execution_mode="install"
  # shellcheck disable=SC2034
  local package_list=()

  if [[ "$CHECK_ONLY" == "1" ]]; then
    execution_mode="check"
  fi

  execution_state_reset
  define_runtime_pipeline package_list
  run_pipeline_steps "$execution_mode"

  if [[ "$execution_mode" == "install" ]]; then
    print_summary
  fi
}
