#!/usr/bin/env bash
# shellcheck shell=bash

ensure_temp_clipboard_utility() {
  local missing_packages=()

  if command -v wl-copy >/dev/null 2>&1; then
    return 0
  fi

  collect_missing_packages missing_packages "${TEMPORARY_CLIPBOARD_PACKAGES[@]}"
  if ((${#missing_packages[@]} == 0)); then
    return 0
  fi

  announce_detail "Instalando wl-clipboard temporariamente para copiar o código do GitHub..."
  if ! ops_pacman_install_needed "${missing_packages[@]}"; then
    announce_warning "Não foi possível instalar wl-clipboard. Continuando sem cópia automática."
    return 1
  fi

  temp_clipboard_package="wl-clipboard"
  return 0
}

cleanup_temp_clipboard_utility() {
  if [[ -z "$temp_clipboard_package" ]]; then
    return 0
  fi

  announce_detail "Removendo $temp_clipboard_package instalado temporariamente..."
  if ! ops_pacman_remove_recursive "$temp_clipboard_package"; then
    announce_warning "Não foi possível remover $temp_clipboard_package automaticamente."
    return 1
  fi

  temp_clipboard_package=""
}
