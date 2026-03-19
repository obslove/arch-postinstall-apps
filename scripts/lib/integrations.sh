#!/usr/bin/env bash
# shellcheck shell=bash
# shellcheck disable=SC2034
# shellcheck source-path=SCRIPTDIR
# shellcheck source=scripts/lib/shellcheck-runtime.sh
# shellcheck source=scripts/lib/ops.sh
# shellcheck source=scripts/lib/status.sh
# shellcheck source=scripts/lib/components.sh

if false; then
  source "$SCRIPT_DIR/scripts/lib/shellcheck-runtime.sh"
  source "$SCRIPT_DIR/scripts/lib/ops.sh"
  source "$SCRIPT_DIR/scripts/lib/status.sh"
  source "$SCRIPT_DIR/scripts/lib/components.sh"
fi

confirm_exclusive_github_ssh_key() {
  local response=""

  if [[ "$EXCLUSIVE_GITHUB_SSH_KEY" != "1" ]]; then
    return 0
  fi

  announce_warning "A opção --exclusive-key removerá as outras chaves SSH da sua conta no GitHub."
  emit_notice "?" "$style_step" "Confirma essa remoção? Digite 'sim' para continuar:"
  if [[ ! -r /dev/tty ]]; then
    announce_warning "Não foi possível ler a confirmação no terminal. A remoção das outras chaves foi cancelada."
    return 1
  fi
  IFS= read -r response </dev/tty || true
  if [[ "$response" != "sim" ]]; then
    announce_warning "A remoção das outras chaves SSH do GitHub foi cancelada."
    return 1
  fi

  return 0
}

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

desktop_integration_ready() {
  local package_name

  for package_name in "${DESKTOP_INTEGRATION_PACKAGES[@]}"; do
    if ! pacman -Q "$package_name" >/dev/null 2>&1; then
      return 1
    fi
  done

  return 0
}

component_detect_desktop_integration() {
  desktop_integration_ready
}

component_checkpoint_key_desktop_integration() {
  printf '%s\n' "desktop_integration"
}

component_apply_desktop_integration() {
  local package_name
  local missing_packages=()

  state_reset_environment_packages
  for package_name in "${DESKTOP_INTEGRATION_PACKAGES[@]}"; do
    mark_environment_package "$package_name"
  done

  if desktop_integration_ready; then
    desktop_integration_status="$STATUS_SKIPPED_READY"
    if ! component_has_checkpoint "desktop_integration" && ! component_mark_checkpoint_if_missing "desktop_integration"; then
      announce_warning "Não foi possível registrar o checkpoint da integração desktop."
    fi
    announce_detail "A integração desktop já está preparada. Etapa ignorada."
    return 0
  fi

  collect_missing_packages missing_packages "${DESKTOP_INTEGRATION_PACKAGES[@]}"
  announce_detail "Garantindo integração desktop..."
  if ! ops_pacman_install_needed "${missing_packages[@]}"; then
    desktop_integration_status="$STATUS_HARD_FAILED"
    announce_error "Não foi possível instalar a integração desktop."
    return 1
  fi

  if ! mark_checkpoint "desktop_integration"; then
    desktop_integration_status="$STATUS_HARD_FAILED"
    announce_error "Não foi possível registrar o checkpoint da integração desktop."
    return 1
  fi

  desktop_integration_status="$STATUS_DONE"
}

ensure_desktop_integration() {
  component_apply desktop_integration
}

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

remove_other_github_ssh_keys() {
  local current_key_id="$1"
  local existing_keys
  local key_id
  local _key_name
  local _key_value

  [[ -n "$current_key_id" ]] || {
    announce_warning "Não foi possível identificar a chave SSH atual para remover as demais."
    return 1
  }

  if ! existing_keys="$(gh api user/keys --jq '.[] | [.id, .title, .key] | @tsv' 2>/dev/null)"; then
    announce_warning "Não foi possível listar as chaves SSH atuais do GitHub."
    return 1
  fi

  announce_detail "Removendo as outras chaves SSH do GitHub..."
  while IFS=$'\t' read -r key_id _key_name _key_value; do
    [[ -n "$key_id" ]] || continue
    [[ "$key_id" == "$current_key_id" ]] && continue
    if ! ops_gh_delete_ssh_key "$key_id"; then
      announce_warning "Não foi possível remover uma das chaves SSH antigas do GitHub."
      return 1
    fi
  done <<<"$existing_keys"
}

setup_codex_cli() {
  local codex_path_line="export PATH=\"\$HOME/Codex/bin:\$PATH\""
  local fish_codex_path_marker="if not contains \"\$HOME/Codex/bin\" \$PATH"
  local fish_codex_path_block="if not contains \"\$HOME/Codex/bin\" \$PATH
    set -gx PATH \"\$HOME/Codex/bin\" \$PATH
end"

  if has_checkpoint "codex_cli" && command -v codex >/dev/null 2>&1; then
    announce_detail "O Codex CLI já está configurado. Etapa ignorada."
    return
  fi

  require_command npm

  announce_detail "Configurando o prefixo do npm em $HOME/Codex..."
  if ! ops_npm_config_set_prefix "$HOME/Codex"; then
    announce_error "Não foi possível configurar o prefixo do npm para o Codex CLI."
    return 1
  fi

  if [[ ! -f "$BASHRC_FILE" ]]; then
    touch "$BASHRC_FILE"
  fi

  if ! grep -qxF "$codex_path_line" "$BASHRC_FILE"; then
    printf '\n%s\n' "$codex_path_line" >>"$BASHRC_FILE"
  fi

  if [[ ! -f "$ZSHRC_FILE" ]]; then
    touch "$ZSHRC_FILE"
  fi

  if ! grep -qxF "$codex_path_line" "$ZSHRC_FILE"; then
    printf '\n%s\n' "$codex_path_line" >>"$ZSHRC_FILE"
  fi

  mkdir -p "$(dirname "$FISH_CONFIG_FILE")"
  if [[ ! -f "$FISH_CONFIG_FILE" ]]; then
    touch "$FISH_CONFIG_FILE"
  fi

  if ! grep -qxF "$fish_codex_path_marker" "$FISH_CONFIG_FILE"; then
    printf '\n%s\n' "$fish_codex_path_block" >>"$FISH_CONFIG_FILE"
  fi

  export PATH="$HOME/Codex/bin:$PATH"

  announce_detail "Instalando Codex CLI em $HOME/Codex..."
  if ! ops_npm_install_codex_cli; then
    announce_error "Não foi possível instalar o Codex CLI."
    return 1
  fi

  if ! mark_checkpoint "codex_cli"; then
    announce_error "Não foi possível registrar o checkpoint do Codex CLI."
    return 1
  fi
}

ensure_ssh_key() {
  local ssh_dir
  local host_name
  local key_comment

  ssh_dir="$(dirname "$SSH_KEY_PATH")"
  mkdir -p "$ssh_dir"
  chmod 700 "$ssh_dir"

  if [[ -f "$SSH_KEY_PATH" ]]; then
    if [[ ! -f "${SSH_KEY_PATH}.pub" ]]; then
      announce_detail "A chave pública SSH não foi encontrada. Recriando ${SSH_KEY_PATH}.pub..."
      if ! ops_ssh_regenerate_public_key "$SSH_KEY_PATH" "${SSH_KEY_PATH}.pub"; then
        announce_error "Não foi possível recriar a chave pública SSH."
        return 1
      fi
      chmod 644 "${SSH_KEY_PATH}.pub"
    fi
    announce_detail "A chave SSH já existe em $SSH_KEY_PATH."
    return 0
  fi

  key_comment="$(git config --global user.email 2>/dev/null || true)"
  if [[ -z "$key_comment" ]]; then
    host_name="$(sanitize_label "$(get_host_name)")"
    key_comment="${USER}@${host_name}"
  fi

  announce_detail "Criando chave SSH em $SSH_KEY_PATH..."
  if ! ops_ssh_generate_key_pair "$key_comment" "$SSH_KEY_PATH"; then
    announce_error "Não foi possível criar a chave SSH."
    return 1
  fi

  return 0
}

ensure_github_auth() {
  if gh auth status >/dev/null 2>&1; then
    announce_detail "GitHub CLI já autenticado."
    return
  fi

  announce_prompt "Autenticando no GitHub com gh..."
  ops_gh_auth_login
}

upload_ssh_key() {
  local current_key
  local current_key_id=""
  local current_key_name=""
  local existing_keys
  local key_id
  local key_name_from_api
  local key_value
  local key_name

  if ! current_key="$(current_public_ssh_key)"; then
    announce_warning "A chave pública SSH atual não está disponível."
    return 1
  fi
  if [[ -z "$current_key" ]]; then
    announce_warning "A chave pública SSH atual está vazia ou inválida."
    return 1
  fi
  key_name="$(build_ssh_key_name)"
  if ! existing_keys="$(gh api user/keys --jq '.[] | [.id, .title, .key] | @tsv' 2>/dev/null)"; then
    announce_detail "A permissão admin:public_key não está disponível no gh. A autenticação será renovada."
    if ! ops_gh_auth_refresh_admin_public_key; then
      announce_warning "Não foi possível renovar o escopo admin:public_key no gh."
      return 1
    fi

    if ! existing_keys="$(gh api user/keys --jq '.[] | [.id, .title, .key] | @tsv' 2>/dev/null)"; then
      announce_warning "O gh continua sem acesso para gerenciar chaves SSH no GitHub."
      return 1
    fi
  fi

  while IFS=$'\t' read -r key_id key_name_from_api key_value; do
    [[ -n "$key_id" ]] || continue
    [[ -n "${key_value:-}" ]] || continue
    if [[ "$key_value" == "$current_key" ]]; then
      current_key_id="$key_id"
      current_key_name="$key_name_from_api"
      break
    fi
  done <<<"$existing_keys"

  if [[ -n "$current_key_id" && "$current_key_name" != "$key_name" ]]; then
    announce_detail "A chave SSH atual já existe no GitHub com outro título. Recriando com o nome correto..."
    if ! ops_gh_delete_ssh_key "$current_key_id"; then
      announce_warning "Não foi possível remover a chave SSH antiga com título incorreto."
      return 1
    fi
    current_key_id=""
  fi

  if [[ -z "$current_key_id" ]]; then
    announce_detail "Enviando a chave SSH ao GitHub..."
    if ! current_key_id="$(ops_gh_create_ssh_key "$key_name" "$current_key")"; then
      announce_warning "Não foi possível enviar a chave SSH atual ao GitHub."
      return 1
    fi
    if [[ -z "$current_key_id" || ! "$current_key_id" =~ ^[0-9]+$ ]]; then
      announce_warning "O GitHub não retornou um identificador válido para a chave SSH enviada."
      return 1
    fi
  else
    announce_detail "A chave SSH atual já existe no GitHub."
  fi

  if ! github_has_expected_ssh_key_name; then
    announce_warning "A chave SSH foi enviada, mas o título esperado no GitHub não pôde ser confirmado."
    return 1
  fi

  if [[ "$EXCLUSIVE_GITHUB_SSH_KEY" == "1" ]]; then
    if ! remove_other_github_ssh_keys "$current_key_id"; then
      return 1
    fi
  fi
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
    github_ssh_status="$STATUS_SKIPPED_DISABLED"
    announce_detail "A configuração do GitHub SSH foi desativada por opção."
    return
  fi

  if ! confirm_exclusive_github_ssh_key; then
    github_ssh_status="$STATUS_SKIPPED_DECLINED"
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
    github_ssh_status="$STATUS_SKIPPED_READY"
    if ! ensure_repo_origin_remote "$SCRIPT_DIR"; then
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
      github_ssh_status="$STATUS_SOFT_FAILED"
      announce_warning "Não foi possível instalar github-cli/openssh. A configuração do GitHub será ignorada."
      return
    fi
  else
    announce_detail "As dependências do GitHub SSH já estão disponíveis."
  fi

  if ! command -v gh >/dev/null 2>&1 || ! command -v ssh-keygen >/dev/null 2>&1; then
    github_ssh_status="$STATUS_SOFT_FAILED"
    announce_warning "github-cli ou ssh-keygen está indisponível. A configuração do GitHub será ignorada."
    return
  fi

  if ! ensure_ssh_key; then
    github_ssh_status="$STATUS_SOFT_FAILED"
    announce_warning "Não foi possível preparar a chave SSH local. A configuração do GitHub será ignorada."
    return
  fi

  if ! ensure_github_auth; then
    cleanup_temp_clipboard_utility || true
    github_ssh_status="$STATUS_SOFT_FAILED"
    announce_warning "A autenticação do GitHub não foi concluída. O envio da chave SSH será ignorado."
    return
  fi

  if ! upload_ssh_key; then
    cleanup_temp_clipboard_utility || true
    github_ssh_status="$STATUS_SOFT_FAILED"
    announce_warning "Não foi possível enviar a chave SSH para o GitHub."
    return
  fi

  cleanup_temp_clipboard_utility || true
  if ! mark_checkpoint "github_ssh"; then
    github_ssh_status="$STATUS_SOFT_FAILED"
    announce_warning "A chave SSH foi configurada, mas o checkpoint do GitHub SSH não pôde ser registrado."
    return
  fi
  github_ssh_status="$STATUS_DONE"
  if ! ensure_repo_origin_remote "$SCRIPT_DIR"; then
    announce_warning "A chave SSH foi configurada, mas não foi possível ajustar o remoto do repositório para SSH."
  fi
}

setup_github_ssh() {
  component_apply github_ssh
}
