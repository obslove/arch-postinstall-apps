#!/usr/bin/env bash
# shellcheck shell=bash

repo_is_dirty() {
  ! git -C "$INSTALL_DIR" diff --quiet --no-ext-diff || \
    ! git -C "$INSTALL_DIR" diff --cached --quiet --no-ext-diff || \
    [[ -n "$(git -C "$INSTALL_DIR" status --porcelain --untracked-files=normal)" ]]
}

sync_repo() {
  local current_branch=""
  local fetched_origin=0

  mkdir -p "$(dirname "$INSTALL_DIR")"

  if [[ -d "$INSTALL_DIR/.git" ]]; then
    announce_step "Atualizando repositório..."
    if repo_is_dirty; then
      current_branch="$(get_repo_branch "$INSTALL_DIR" 2>/dev/null || true)"
      if [[ -n "$current_branch" && "$current_branch" != "main" ]]; then
        announce_error "O clone gerenciado está com mudanças locais na branch '$current_branch'."
        announce_error "Não dá para executar com segurança a branch 'main' sem limpar ou mover essas mudanças."
        return 1
      fi

      announce_warning "O repositório local tem alterações. A atualização automática será ignorada."
      return 0
    fi

    if ! ensure_repo_origin_remote "$INSTALL_DIR" "$REPO_HTTPS_URL"; then
      announce_error "Não foi possível ajustar o remoto origin do clone gerenciado."
      return 1
    fi

    if retry_log_only git -C "$INSTALL_DIR" fetch origin; then
      fetched_origin=1
    else
      announce_warning "Falha ao buscar atualizações de origin. O script tentará usar a cópia local."
    fi

    if git -C "$INSTALL_DIR" show-ref --verify --quiet "refs/heads/main"; then
      if ! run_log_only git -C "$INSTALL_DIR" checkout main; then
        announce_error "Não foi possível trocar para a branch local 'main'."
        return 1
      fi
    elif git -C "$INSTALL_DIR" show-ref --verify --quiet "refs/remotes/origin/main"; then
      if ! run_log_only git -C "$INSTALL_DIR" checkout -b main origin/main; then
        announce_error "Não foi possível criar a branch local 'main' a partir de origin."
        return 1
      fi
    elif [[ "$fetched_origin" == "0" ]]; then
      announce_error "Não foi possível atualizar origin e a branch 'main' não existe localmente."
      announce_error "Verifique acesso ao GitHub ou recupere um clone local válido."
      return 1
    else
      announce_error "Branch 'main' não encontrada no repositório local nem em origin."
      return 1
    fi

    if [[ "$fetched_origin" == "0" ]]; then
      announce_warning "O 'git pull' será ignorado porque o fetch de origin falhou. O script continuará com a branch local."
      return 0
    fi

    if ! retry_log_only git -C "$INSTALL_DIR" pull --ff-only origin main; then
      announce_warning "Falha ao atualizar 'main' com 'git pull --ff-only'. O script continuará com a cópia atual."
    fi
    return 0
  fi

  if [[ -e "$INSTALL_DIR" ]]; then
    announce_error "$INSTALL_DIR já existe e não é um repositório git."
    return 1
  fi

  announce_step "Clonando repositório..."
  if ! retry_log_only git clone --branch main --single-branch "$REPO_HTTPS_URL" "$INSTALL_DIR"; then
    announce_error "Falha ao clonar 'main' de $REPO_HTTPS_URL."
    announce_error "Verifique acesso ao GitHub e se a branch existe no remoto."
    return 1
  fi
}
