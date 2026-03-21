#!/usr/bin/env bash
# shellcheck shell=bash

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

  if ! existing_keys="$(ops_gh_list_ssh_keys_tsv 2>/dev/null)"; then
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

upload_ssh_key() {
  local current_key
  local current_key_id=""
  local current_key_name=""
  local existing_keys
  local key_id
  local key_name_from_api
  local key_value
  local key_name
  local should_reconcile_key_name=0

  if ! current_key="$(current_public_ssh_key)"; then
    announce_warning "A chave pública SSH atual não está disponível."
    return 1
  fi
  if [[ -z "$current_key" ]]; then
    announce_warning "A chave pública SSH atual está vazia ou inválida."
    return 1
  fi
  key_name="$(build_ssh_key_name)"
  if github_ssh_explicit_name_requested; then
    should_reconcile_key_name=1
  fi
  if ! existing_keys="$(ops_gh_list_ssh_keys_tsv 2>/dev/null)"; then
    announce_detail "A permissão admin:public_key não está disponível no gh. A autenticação será renovada."
    if ! ops_gh_auth_refresh_admin_public_key; then
      announce_warning "Não foi possível renovar o escopo admin:public_key no gh."
      return 1
    fi

    if ! existing_keys="$(ops_gh_list_ssh_keys_tsv 2>/dev/null)"; then
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

  if [[ "$should_reconcile_key_name" == "1" && -n "$current_key_id" && "$current_key_name" != "$key_name" ]]; then
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
