#!/usr/bin/env bash
# shellcheck shell=bash

run_gh_auth_flow() {
  local clipboard_args=()

  announce_prompt "Iniciando a autenticação do GitHub..."
  if ensure_temp_clipboard_utility; then
    clipboard_args+=(--clipboard)
    announce_detail "O código de dispositivo será copiado automaticamente para a área de transferência."
  else
    announce_warning "Área de transferência indisponível. Copie o código manualmente no terminal."
  fi

  if [[ -t 0 ]]; then
    printf '\n' | run_with_terminal_stdin gh "$@" "${clipboard_args[@]}"
    return
  fi

  run_with_terminal_stdin gh "$@" "${clipboard_args[@]}"
}

ensure_github_auth() {
  if gh auth status >/dev/null 2>&1; then
    announce_detail "GitHub CLI já autenticado."
    return
  fi

  announce_prompt "Autenticando no GitHub com gh..."
  ops_gh_auth_login
}
