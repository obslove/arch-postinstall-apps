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
    github_login="$(gh api user --jq '.login' 2>/dev/null || true)"
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

  current_key="$(current_public_ssh_key)" || return 1
  gh api user/keys --jq ".[] | select(.key == \"$current_key\") | [.id, .title] | @tsv"
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
  has_checkpoint "github_ssh" || return 1
  github_has_expected_ssh_key_name
}

component_detect_github_ssh() {
  github_ssh_ready
}

component_checkpoint_key_github_ssh() {
  printf '%s\n' "github_ssh"
}

component_apply_github_ssh() {
  local github_ssh_already_ready=0
  local missing_packages=()

  if ! github_ssh_expected; then
    state_set_component_status github_ssh "$STATUS_SKIPPED_DISABLED"
    announce_detail "A configuração do GitHub SSH foi desativada por opção."
    return
  fi

  if ! confirm_exclusive_github_ssh_key; then
    state_set_component_status github_ssh "$STATUS_SKIPPED_DECLINED"
    return
  fi

  announce_detail "Verificando estado atual do GitHub SSH..."
  if has_checkpoint "github_ssh"; then
    announce_detail "Checkpoint do GitHub SSH encontrado. Conferindo autenticação e chave atual..."
    if ! github_ssh_force_reconcile && command -v gh >/dev/null 2>&1 && gh auth status >/dev/null 2>&1 && github_has_expected_ssh_key_name; then
      github_ssh_already_ready=1
    fi
  fi

  if [[ "$github_ssh_already_ready" == "1" ]]; then
    state_set_component_status github_ssh "$STATUS_SKIPPED_READY"
    if ! ensure_repo_origin_remote "$SCRIPT_DIR" "$REPO_SSH_URL"; then
      announce_warning "Não foi possível ajustar o remoto do repositório para SSH."
    fi
    announce_detail "O GitHub SSH já está configurado. Etapa ignorada."
    return
  fi

  announce_detail "Registrando dependências da etapa de GitHub SSH..."
  for package_name in "${GITHUB_SSH_SUPPORT_PACKAGES[@]}"; do
    mark_support_package "$package_name"
  done
  announce_detail "Verificando dependências da etapa de GitHub SSH..."
  collect_missing_packages missing_packages "${GITHUB_SSH_SUPPORT_PACKAGES[@]}"
  if ((${#missing_packages[@]} > 0)); then
    if ! ops_pacman_install_needed "${missing_packages[@]}"; then
      state_set_component_status github_ssh "$STATUS_SOFT_FAILED"
      announce_warning "Não foi possível instalar github-cli/openssh. A configuração do GitHub será ignorada."
      return
    fi
  else
    announce_detail "As dependências do GitHub SSH já estão disponíveis."
  fi

  if ! command -v gh >/dev/null 2>&1 || ! command -v ssh-keygen >/dev/null 2>&1; then
    state_set_component_status github_ssh "$STATUS_SOFT_FAILED"
    announce_warning "github-cli ou ssh-keygen está indisponível. A configuração do GitHub será ignorada."
    return
  fi

  if ! ensure_ssh_key; then
    state_set_component_status github_ssh "$STATUS_SOFT_FAILED"
    announce_warning "Não foi possível preparar a chave SSH local. A configuração do GitHub será ignorada."
    return
  fi

  if ! ensure_github_auth; then
    cleanup_temp_clipboard_utility || true
    state_set_component_status github_ssh "$STATUS_SOFT_FAILED"
    announce_warning "A autenticação do GitHub não foi concluída. O envio da chave SSH será ignorado."
    return
  fi

  if ! upload_ssh_key; then
    cleanup_temp_clipboard_utility || true
    state_set_component_status github_ssh "$STATUS_SOFT_FAILED"
    announce_warning "Não foi possível enviar a chave SSH para o GitHub."
    return
  fi

  cleanup_temp_clipboard_utility || true
  if ! mark_checkpoint "github_ssh"; then
    state_set_component_status github_ssh "$STATUS_SOFT_FAILED"
    announce_warning "A chave SSH foi configurada, mas o checkpoint do GitHub SSH não pôde ser registrado."
    return
  fi
  state_set_component_status github_ssh "$STATUS_DONE"
  if ! ensure_repo_origin_remote "$SCRIPT_DIR" "$REPO_SSH_URL"; then
    announce_warning "A chave SSH foi configurada, mas não foi possível ajustar o remoto do repositório para SSH."
  fi
}

component_verify_github_ssh() {
  local package_name

  for package_name in "${GITHUB_SSH_SUPPORT_PACKAGES[@]}"; do
    case "$package_name" in
      github-cli)
        verify_command "github-cli" "gh"
        ;;
      openssh)
        verify_command "openssh" "ssh-keygen"
        ;;
    esac
  done
  if [[ "$(current_repo_origin_status "$SCRIPT_DIR")" == "ssh" ]]; then
    mark_verified_item "origin-ssh"
  else
    mark_missing_item "origin-ssh"
  fi
}
