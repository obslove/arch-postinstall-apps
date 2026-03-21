#!/usr/bin/env bash
# shellcheck shell=bash
# shellcheck disable=SC2034

bootstrap_check_dependencies_step() {
  local array_name="$1"
  # shellcheck disable=SC2178
  declare -n missing_packages="$array_name"

  step_result_reset

  if ((${#missing_packages[@]} == 0)); then
    announce_detail "As dependências iniciais já estão disponíveis."
    step_result_success "As dependências iniciais já estavam disponíveis."
    return 0
  fi

  announce_detail "${#missing_packages[@]} dependência(s) inicial(is) ainda não instalada(s)."
  step_result_success "As dependências iniciais foram avaliadas."
}

bootstrap_install_dependencies_step() {
  local array_name="${1:-BOOTSTRAP_MISSING_PACKAGES}"
  # shellcheck disable=SC2178
  declare -n missing_packages="$array_name"

  step_result_reset

  if ((${#missing_packages[@]} == 0)); then
    announce_detail "As dependências iniciais já estão disponíveis. Etapa ignorada."
    step_result_skipped "As dependências iniciais já estavam disponíveis."
    return 0
  fi

  if ops_pacman_upgrade_and_install_needed "${missing_packages[@]}"; then
    BOOTSTRAP_SYSTEM_UPDATED=1
    step_result_success "As dependências iniciais foram instaladas."
    return 0
  fi

  step_result_hard_fail "Não foi possível instalar as dependências iniciais."
}
