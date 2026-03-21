#!/usr/bin/env bash
# shellcheck shell=bash

ensure_not_root() {
  if [[ "${EUID:-$(id -u)}" -eq 0 ]]; then
    announce_error "Execute este script como usuário comum, e não como root."
    exit 1
  fi
}

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    announce_error "Comando obrigatório não encontrado: $1"
    exit 1
  fi
}

canonicalize_path() {
  if ! command -v realpath >/dev/null 2>&1; then
    announce_error "Comando obrigatório não encontrado: realpath"
    return 1
  fi

  realpath -m -- "$1"
}

require_exact_path() {
  local label="$1"
  local actual_path="$2"
  local expected_path="$3"
  local resolved_actual=""
  local resolved_expected=""

  [[ -n "$actual_path" && -n "$expected_path" ]] || {
    announce_error "Caminho inválido para $label."
    return 1
  }

  resolved_actual="$(canonicalize_path "$actual_path")" || return 1
  resolved_expected="$(canonicalize_path "$expected_path")" || return 1

  if [[ "$resolved_actual" != "$resolved_expected" ]]; then
    announce_error "$label fora do caminho gerenciado esperado: $actual_path"
    announce_error "Esperado: $resolved_expected"
    return 1
  fi
}

validate_managed_paths() {
  local expected_repositories_dir="$HOME/Repositories"
  local expected_install_dir="$expected_repositories_dir/arch-postinstall-apps"
  local expected_yay_repo_dir="$expected_repositories_dir/yay"
  local expected_state_dir="${XDG_STATE_HOME:-$HOME/.local/state}/arch-postinstall-apps"
  local expected_lock_dir="$expected_state_dir/lock"

  require_exact_path "REPOSITORIES_DIR" "$REPOSITORIES_DIR" "$expected_repositories_dir" || exit 1
  require_exact_path "INSTALL_DIR" "$INSTALL_DIR" "$expected_install_dir" || exit 1
  require_exact_path "YAY_REPO_DIR" "$YAY_REPO_DIR" "$expected_yay_repo_dir" || exit 1
  require_exact_path "STATE_DIR" "$STATE_DIR" "$expected_state_dir" || exit 1
  require_exact_path "LOCK_DIR" "$LOCK_DIR" "$expected_lock_dir" || exit 1
}

get_host_name() {
  if command -v hostname >/dev/null 2>&1; then
    hostname
    return
  fi

  if command -v hostnamectl >/dev/null 2>&1; then
    hostnamectl hostname 2>/dev/null
    return
  fi

  if [[ -f /etc/hostname ]]; then
    cat /etc/hostname
    return
  fi

  uname -n
}

sanitize_label() {
  printf '%s' "$1" | tr -cs '[:alnum:].@_-' '-'
}

is_wayland_session() {
  [[ "${XDG_SESSION_TYPE:-}" == "wayland" || -n "${WAYLAND_DISPLAY:-}" ]]
}

is_hyprland_session() {
  [[ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]] || \
    [[ "${XDG_CURRENT_DESKTOP:-}" == *Hyprland* ]] || \
    [[ "${DESKTOP_SESSION:-}" == "hyprland" ]]
}

is_supported_session() {
  is_wayland_session && is_hyprland_session
}

ensure_supported_session() {
  if is_supported_session; then
    return 0
  fi

  announce_error "Este script foi ajustado para Wayland com Hyprland."
  announce_error "Sessão atual: XDG_SESSION_TYPE='${XDG_SESSION_TYPE:-}', XDG_CURRENT_DESKTOP='${XDG_CURRENT_DESKTOP:-}', DESKTOP_SESSION='${DESKTOP_SESSION:-}'"
  exit 1
}

ensure_arch() {
  if [[ ! -f /etc/arch-release ]]; then
    announce_error "Este script foi feito para Arch Linux."
    exit 1
  fi
}

github_ssh_expected() {
  [[ "$SKIP_GITHUB_SSH" != "1" ]]
}

github_ssh_force_reconcile() {
  [[ "$EXCLUSIVE_GITHUB_SSH_KEY" == "1" || -n "$GITHUB_SSH_KEY_NAME" ]]
}
