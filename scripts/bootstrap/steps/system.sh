#!/usr/bin/env bash
# shellcheck shell=bash

bootstrap_validate_environment_step() {
  step_result_reset

  if ! ensure_arch; then
    step_result_hard_fail "Este bootstrap só pode ser executado em Arch Linux."
    return 0
  fi

  if ! ensure_supported_session; then
    step_result_hard_fail "A sessão atual não é compatível com o bootstrap."
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
  step_result_success "O ambiente de bootstrap foi validado."
}
