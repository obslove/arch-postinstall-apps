#!/usr/bin/env bash
# shellcheck shell=bash

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
