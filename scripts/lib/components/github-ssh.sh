#!/usr/bin/env bash
# shellcheck shell=bash
# shellcheck disable=SC2034
# shellcheck source-path=SCRIPTDIR
# shellcheck source=scripts/lib/shellcheck-runtime.sh
# shellcheck source=scripts/lib/ops.sh
# shellcheck source=scripts/lib/status.sh
# shellcheck source=scripts/lib/components.sh
# shellcheck source=scripts/lib/repo.sh
# shellcheck source=scripts/lib/components/github-ssh/clipboard.sh
# shellcheck source=scripts/lib/components/github-ssh/auth.sh
# shellcheck source=scripts/lib/components/github-ssh/key.sh
# shellcheck source=scripts/lib/components/github-ssh/publish.sh

if false; then
  source "$SCRIPT_DIR/scripts/lib/shellcheck-runtime.sh"
  source "$SCRIPT_DIR/scripts/lib/ops.sh"
  source "$SCRIPT_DIR/scripts/lib/status.sh"
  source "$SCRIPT_DIR/scripts/lib/components.sh"
  source "$SCRIPT_DIR/scripts/lib/repo.sh"
  source "$SCRIPT_DIR/scripts/lib/components/github-ssh/clipboard.sh"
  source "$SCRIPT_DIR/scripts/lib/components/github-ssh/auth.sh"
  source "$SCRIPT_DIR/scripts/lib/components/github-ssh/key.sh"
  source "$SCRIPT_DIR/scripts/lib/components/github-ssh/publish.sh"
fi

GITHUB_SSH_COMPONENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)/github-ssh"
# shellcheck source=github-ssh/clipboard.sh
source "$GITHUB_SSH_COMPONENT_DIR/clipboard.sh"
# shellcheck source=github-ssh/auth.sh
source "$GITHUB_SSH_COMPONENT_DIR/auth.sh"
# shellcheck source=github-ssh/key.sh
source "$GITHUB_SSH_COMPONENT_DIR/key.sh"
# shellcheck source=github-ssh/publish.sh
source "$GITHUB_SSH_COMPONENT_DIR/publish.sh"

build_ssh_key_name() {
  local github_login=""

  if [[ -n "$GITHUB_SSH_KEY_NAME" ]]; then
    printf '%s\n' "$GITHUB_SSH_KEY_NAME"
    return
  fi

  if command -v gh >/dev/null 2>&1; then
    github_login="$(ops_gh_get_authenticated_login 2>/dev/null || true)"
    if [[ -n "$github_login" ]]; then
      printf '%s\n' "$github_login"
      return
    fi
  fi

  printf '%s\n' "$USER"
}

current_public_ssh_key() {
  [[ -f "${SSH_KEY_PATH}.pub" ]] || return 1
  awk 'NR == 1 { print $1, $2 }' "${SSH_KEY_PATH}.pub"
}

find_current_github_ssh_key() {
  local current_key
  local existing_keys=""
  local key_id=""
  local key_name=""
  local key_value=""

  current_key="$(current_public_ssh_key)" || return 1
  existing_keys="$(ops_gh_list_ssh_keys_tsv 2>/dev/null || true)"
  [[ -n "$existing_keys" ]] || return 1

  while IFS=$'\t' read -r key_id key_name key_value; do
    [[ -n "$key_id" && -n "${key_value:-}" ]] || continue
    if [[ "$key_value" == "$current_key" ]]; then
      printf '%s\t%s\n' "$key_id" "$key_name"
      return 0
    fi
  done <<<"$existing_keys"

  return 1
}

github_has_expected_ssh_key_name() {
  local key_data
  local current_key_name=""

  key_data="$(find_current_github_ssh_key 2>/dev/null || true)"
  [[ -n "$key_data" ]] || return 1
  IFS=$'\t' read -r _ current_key_name <<<"$key_data"
  [[ "$current_key_name" == "$(build_ssh_key_name)" ]]
}

github_ssh_ready() {
  [[ -f "${SSH_KEY_PATH}.pub" ]] || return 1
  command -v gh >/dev/null 2>&1 || return 1
  gh auth status >/dev/null 2>&1 || return 1
  [[ "$(current_repo_origin_status "$SCRIPT_DIR")" == "ssh" ]] || return 1
  github_has_expected_ssh_key_name
}

component_detect_github_ssh() {
  github_ssh_ready
}

component_apply_github_ssh() {
  local missing_packages=()
  local package_name

  if ! github_ssh_expected; then
    report_set_component_outcome "github_ssh" "$COMPONENT_OUTCOME_DISABLED"
    announce_detail "A configuração do GitHub SSH foi desativada por opção."
    return
  fi

  if ! confirm_exclusive_github_ssh_key; then
    report_set_component_outcome "github_ssh" "$COMPONENT_OUTCOME_DECLINED"
    return
  fi

  announce_detail "Verificando estado atual do GitHub SSH..."
  if ! github_ssh_force_reconcile && github_ssh_ready; then
    report_set_component_outcome "github_ssh" "$COMPONENT_OUTCOME_REUSED"
    announce_detail "O GitHub SSH já está configurado. Etapa ignorada."
    return
  fi

  if has_checkpoint "github_ssh"; then
    announce_detail "Checkpoint do GitHub SSH encontrado. Conferindo autenticação e chave atual..."
  fi

  announce_detail "Registrando dependências da etapa de GitHub SSH..."
  for package_name in "${GITHUB_SSH_SUPPORT_PACKAGES[@]}"; do
    report_add_requested_support_package "$package_name"
  done
  announce_detail "Verificando dependências da etapa de GitHub SSH..."
  collect_missing_packages missing_packages "${GITHUB_SSH_SUPPORT_PACKAGES[@]}"
  if ((${#missing_packages[@]} > 0)); then
    if ! ops_pacman_install_needed "${missing_packages[@]}"; then
      report_set_component_outcome "github_ssh" "$COMPONENT_OUTCOME_SOFT_FAILED"
      announce_warning "Não foi possível instalar github-cli/openssh. A configuração do GitHub será ignorada."
      return
    fi
    for package_name in "${missing_packages[@]}"; do
      report_add_changed_support_package "$package_name"
    done
  else
    announce_detail "As dependências do GitHub SSH já estão disponíveis."
  fi
  for package_name in "${GITHUB_SSH_SUPPORT_PACKAGES[@]}"; do
    if ! config_array_contains missing_packages "$package_name"; then
      report_add_reused_support_package "$package_name"
    fi
  done

  if ! command -v gh >/dev/null 2>&1 || ! command -v ssh-keygen >/dev/null 2>&1; then
    report_set_component_outcome "github_ssh" "$COMPONENT_OUTCOME_SOFT_FAILED"
    announce_warning "github-cli ou ssh-keygen está indisponível. A configuração do GitHub será ignorada."
    return
  fi

  if ! ensure_ssh_key; then
    report_set_component_outcome "github_ssh" "$COMPONENT_OUTCOME_SOFT_FAILED"
    announce_warning "Não foi possível preparar a chave SSH local. A configuração do GitHub será ignorada."
    return
  fi

  if ! ensure_github_auth; then
    cleanup_temp_clipboard_utility || true
    report_set_component_outcome "github_ssh" "$COMPONENT_OUTCOME_SOFT_FAILED"
    announce_warning "A autenticação do GitHub não foi concluída. O envio da chave SSH será ignorado."
    return
  fi

  if ! upload_ssh_key; then
    cleanup_temp_clipboard_utility || true
    report_set_component_outcome "github_ssh" "$COMPONENT_OUTCOME_SOFT_FAILED"
    announce_warning "Não foi possível enviar a chave SSH para o GitHub."
    return
  fi

  cleanup_temp_clipboard_utility || true
  if ! mark_checkpoint "github_ssh"; then
    report_set_component_outcome "github_ssh" "$COMPONENT_OUTCOME_SOFT_FAILED"
    announce_warning "A chave SSH foi configurada, mas o checkpoint do GitHub SSH não pôde ser registrado."
    return
  fi
  report_set_component_outcome "github_ssh" "$COMPONENT_OUTCOME_CHANGED"
  if ! ensure_repo_origin_remote "$SCRIPT_DIR" "$REPO_SSH_URL"; then
    announce_warning "A chave SSH foi configurada, mas não foi possível ajustar o remoto do repositório para SSH."
  fi
}

component_verify_github_ssh() {
  local package_name

  for package_name in "${GITHUB_SSH_SUPPORT_PACKAGES[@]}"; do
    case "$package_name" in
      github-cli)
        verify_command "github-cli" "github-cli" "gh" "pacman_package" "github-cli"
        ;;
      openssh)
        verify_command "openssh" "openssh" "ssh-keygen" "pacman_package" "openssh"
        ;;
    esac
  done
  if [[ "$(current_repo_origin_status "$SCRIPT_DIR")" == "ssh" ]]; then
    state_add_verified_item "origin-ssh" "origin-ssh" "repo" "repo_origin_ssh" "$SCRIPT_DIR"
  else
    state_add_missing_item "origin-ssh" "origin-ssh" "repo" "repo_origin_ssh" "$SCRIPT_DIR"
  fi
}
