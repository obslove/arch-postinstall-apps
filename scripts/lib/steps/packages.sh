#!/usr/bin/env bash
# shellcheck shell=bash

prepare_aur_helper_step() {
  step_result_reset

  if component_apply aur_helper; then
    step_result_success "O helper AUR foi preparado."
    return 0
  fi

  step_result_hard_fail "Não foi possível preparar o helper AUR padrão para a instalação."
}

install_local_support_packages_step() {
  local missing_packages=()
  local package_name

  step_result_reset

  if ((${#LOCAL_SUPPORT_PACKAGES[@]} == 0)); then
    step_result_skipped "Nenhuma ferramenta de suporte local foi declarada."
    return 0
  fi

  for package_name in "${LOCAL_SUPPORT_PACKAGES[@]}"; do
    state_add_support_package "$package_name"
  done

  collect_missing_packages missing_packages "${LOCAL_SUPPORT_PACKAGES[@]}"
  if ((${#missing_packages[@]} == 0)); then
    step_result_success "As ferramentas de suporte local já estavam disponíveis."
    return 0
  fi

  if ! ops_pacman_install_needed "${missing_packages[@]}"; then
    step_result_hard_fail "Não foi possível instalar as ferramentas de suporte local."
    return 0
  fi

  step_result_success "As ferramentas de suporte local foram instaladas."
}

install_packages_step() {
  local array_name="$1"

  step_result_reset

  if ! install_packages_in_order "$array_name"; then
    step_result_hard_fail "Falha ao executar a instalação dos pacotes configurados."
    return 0
  fi

  if state_has_package_failures; then
    step_result_hard_fail "A instalação terminou com falhas em pacotes configurados."
    return 0
  fi

  step_result_success "Os pacotes configurados foram tratados."
}

pipeline_install_local_support_packages_step() {
  announce_step "Instalando ferramentas de suporte..."
  install_local_support_packages_step
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
