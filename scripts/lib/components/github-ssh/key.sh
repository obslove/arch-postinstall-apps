#!/usr/bin/env bash
# shellcheck shell=bash
# shellcheck disable=SC2154

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
