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
    report_add_requested_support_package "$package_name"
  done

  collect_missing_packages missing_packages "${LOCAL_SUPPORT_PACKAGES[@]}"
  if ((${#missing_packages[@]} == 0)); then
    for package_name in "${LOCAL_SUPPORT_PACKAGES[@]}"; do
      report_add_reused_support_package "$package_name"
    done
    step_result_success "As ferramentas de suporte local já estavam disponíveis."
    return 0
  fi

  if ! ops_pacman_install_needed "${missing_packages[@]}"; then
    step_result_hard_fail "Não foi possível instalar as ferramentas de suporte local."
    return 0
  fi

  for package_name in "${LOCAL_SUPPORT_PACKAGES[@]}"; do
    if ! config_array_contains missing_packages "$package_name"; then
      report_add_reused_support_package "$package_name"
    fi
  done
  for package_name in "${missing_packages[@]}"; do
    report_add_changed_support_package "$package_name"
  done
  step_result_success "As ferramentas de suporte local foram instaladas."
}

prepare_package_installation_step() {
  step_result_reset
  state_reset_package_results
  step_result_success
}

install_official_packages_step() {
  local array_name="$1"

  step_result_reset

  if ! install_official_packages_in_order "$array_name"; then
    step_result_hard_fail "Falha ao instalar os apps oficiais configurados."
    return 0
  fi

  step_result_success "Os apps oficiais configurados foram tratados."
}

install_aur_packages_step() {
  local array_name="$1"

  step_result_reset

  if ! install_aur_packages_in_order "$array_name"; then
    step_result_hard_fail "Falha ao instalar os apps AUR configurados."
    return 0
  fi

  step_result_success "Os apps AUR configurados foram tratados."
}

finalize_package_installation_step() {
  step_result_reset

  if state_has_package_failures; then
    step_result_hard_fail "A instalação terminou com falhas em pacotes configurados."
    return 0
  fi

  step_result_success
}
