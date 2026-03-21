#!/usr/bin/env bash
# shellcheck shell=bash

codex_cli_step() {
  step_result_reset

  if ! component_is_expected codex_cli; then
    step_result_skipped "A configuração do Codex CLI foi desativada por configuração."
    return 0
  fi

  if component_detect codex_cli; then
    step_result_skipped "O Codex CLI já estava configurado."
    return 0
  fi

  if component_apply codex_cli; then
    step_result_success "O Codex CLI foi configurado."
    return 0
  fi

  step_result_hard_fail "A configuração do Codex CLI falhou."
}

pipeline_codex_cli_step() {
  announce_step "Configurando Codex CLI..."
  codex_cli_step
  handle_runtime_step_result_or_exit
}
