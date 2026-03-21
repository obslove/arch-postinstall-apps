#!/usr/bin/env bash
# shellcheck shell=bash

bootstrap_sync_repo_step() {
  step_result_reset

  if ! require_command git; then
    step_result_hard_fail "O comando 'git' é obrigatório para sincronizar o repositório."
    return 0
  fi

  if ! require_command curl; then
    step_result_hard_fail "O comando 'curl' é obrigatório para sincronizar o repositório."
    return 0
  fi

  if ! require_command tar; then
    step_result_hard_fail "O comando 'tar' é obrigatório para sincronizar o repositório."
    return 0
  fi

  if sync_repo; then
    step_result_success "O repositório gerenciado foi sincronizado."
    return 0
  fi

  step_result_hard_fail "Não foi possível sincronizar o repositório gerenciado."
}
