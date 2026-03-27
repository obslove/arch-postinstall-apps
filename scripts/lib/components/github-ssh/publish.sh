#!/usr/bin/env bash
# shellcheck shell=bash

run_github_ssh_api() {
  local output_array_name="$1"
  local operation_label="$2"
  shift 2

  local stdout_file=""
  local stderr_file=""
  local command_status=0
  local stderr_preview=""
  local -a command_args=()
  # shellcheck disable=SC2178
  declare -n output_array="$output_array_name"

  output_array=()
  stdout_file="$(mktemp)" || return 1
  stderr_file="$(mktemp)" || {
    rm -f "$stdout_file"
    return 1
  }

  command_args=(gh api "$@")
  if command -v timeout >/dev/null 2>&1; then
    command_args=(timeout --foreground 30s "${command_args[@]}")
  fi

  if "${command_args[@]}" >"$stdout_file" 2>"$stderr_file"; then
    mapfile -t output_array <"$stdout_file"
    rm -f "$stdout_file" "$stderr_file"
    return 0
  fi

  command_status=$?
  stderr_preview="$(sed -n '1,3p' "$stderr_file" | tr '\n' ' ' | sed 's/[[:space:]]\+/ /g; s/[[:space:]]$//')"
  if [[ -n "$stderr_preview" ]]; then
    announce_warning "$operation_label falhou: $stderr_preview"
  else
    announce_warning "$operation_label falhou sem mensagem do gh."
  fi

  if [[ -s "$stderr_file" ]]; then
    {
      printf '[github-ssh] %s\n' "$operation_label"
      sed 's/^/[gh] /' "$stderr_file"
    } >>"$LOG_FILE"
  fi

  rm -f "$stdout_file" "$stderr_file"
  return "$command_status"
}

github_ssh_list_keys() {
  local output_array_name="$1"

  run_github_ssh_api "$output_array_name" \
    "A listagem das chaves SSH do GitHub" \
    user/keys --jq '.[] | [.id, .title, .key] | @tsv'
}

github_ssh_delete_key() {
  local key_id="$1"
  local gh_output=()

  announce_detail "Removendo chave SSH antiga do GitHub: $key_id"
  run_github_ssh_api gh_output \
    "A remoção da chave SSH do GitHub $key_id" \
    --method DELETE "user/keys/$key_id"
}

github_ssh_create_key() {
  local output_array_name="$1"
  local key_name="$2"
  local public_key="$3"

  run_github_ssh_api "$output_array_name" \
    "O envio da chave SSH atual ao GitHub" \
    user/keys --method POST -f "title=$key_name" -f "key=$public_key" --jq '.id'
}

remove_other_github_ssh_keys() {
  local current_key_id="$1"
  local existing_keys=()
  local key_id
  local _key_name
  local _key_value

  [[ -n "$current_key_id" ]] || {
    announce_warning "Não foi possível identificar a chave SSH atual para remover as demais."
    return 1
  }

  if ! github_ssh_list_keys existing_keys; then
    return 1
  fi

  announce_detail "Removendo as outras chaves SSH do GitHub..."
  while IFS=$'\t' read -r key_id _key_name _key_value; do
    [[ -n "$key_id" ]] || continue
    [[ "$key_id" == "$current_key_id" ]] && continue
    if ! github_ssh_delete_key "$key_id"; then
      announce_warning "Não foi possível remover uma das chaves SSH antigas do GitHub."
      return 1
    fi
  done <<<"$(printf '%s\n' "${existing_keys[@]}")"
}

upload_ssh_key() {
  local current_key
  local current_key_id=""
  local current_key_name=""
  local existing_keys=()
  local created_key_output=()
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
  if ! github_ssh_list_keys existing_keys; then
    announce_detail "A permissão admin:public_key não está disponível no gh. A autenticação será renovada."
    if ! ops_gh_auth_refresh_admin_public_key; then
      announce_warning "Não foi possível renovar o escopo admin:public_key no gh."
      return 1
    fi

    if ! github_ssh_list_keys existing_keys; then
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
  done <<<"$(printf '%s\n' "${existing_keys[@]}")"

  if [[ "$should_reconcile_key_name" == "1" && -n "$current_key_id" && "$current_key_name" != "$key_name" ]]; then
    announce_detail "A chave SSH atual já existe no GitHub com outro título. Recriando com o nome correto..."
    if ! github_ssh_delete_key "$current_key_id"; then
      announce_warning "Não foi possível remover a chave SSH antiga com título incorreto."
      return 1
    fi
    current_key_id=""
  fi

  if [[ -z "$current_key_id" ]]; then
    announce_detail "Enviando a chave SSH ao GitHub..."
    if ! github_ssh_create_key created_key_output "$key_name" "$current_key"; then
      return 1
    fi
    current_key_id="${created_key_output[0]:-}"
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
