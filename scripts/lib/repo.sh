#!/usr/bin/env bash
# shellcheck shell=bash
# shellcheck source-path=SCRIPTDIR
# shellcheck source=scripts/lib/ops.sh

ensure_repo_origin_remote() {
  local repo_dir="$1"
  local desired_origin_url="${2:-$REPO_HTTPS_URL}"
  local current_origin_url=""
  local allowed_origin_urls=()
  local managed_https_url=""
  local managed_ssh_url=""
  local allowed_origin_url=""
  local matches_allowed_origin=1

  current_origin_url="$(git -C "$repo_dir" remote get-url origin 2>/dev/null || true)"

  if [[ -z "$current_origin_url" ]]; then
    ops_git_remote_add_origin "$repo_dir" "$desired_origin_url"
    return
  fi

  allowed_origin_urls=("$REPO_HTTPS_URL" "$REPO_SSH_URL")
  managed_https_url="$(managed_repo_expected_https_origin_url "$repo_dir" 2>/dev/null || true)"
  managed_ssh_url="$(managed_repo_expected_ssh_origin_url "$repo_dir" 2>/dev/null || true)"
  [[ -n "$managed_https_url" ]] && allowed_origin_urls+=("$managed_https_url")
  [[ -n "$managed_ssh_url" ]] && allowed_origin_urls+=("$managed_ssh_url")

  for allowed_origin_url in "${allowed_origin_urls[@]}"; do
    if [[ "$current_origin_url" == "$allowed_origin_url" ]]; then
      matches_allowed_origin=0
      break
    fi
  done

  if [[ "$matches_allowed_origin" != "0" ]]; then
    announce_detail "Foi detectado um remoto origin personalizado em $repo_dir. A configuração atual será mantida."
    return
  fi

  if [[ "$current_origin_url" != "$desired_origin_url" ]]; then
    ops_git_remote_set_origin "$repo_dir" "$desired_origin_url"
  fi
}

get_repo_branch() {
  local repo_dir="$1"
  local branch_name=""

  if ! git -C "$repo_dir" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    return 1
  fi

  branch_name="$(git -C "$repo_dir" symbolic-ref --quiet --short HEAD 2>/dev/null || true)"
  if [[ -n "$branch_name" ]]; then
    printf '%s\n' "$branch_name"
    return 0
  fi

  branch_name="$(git -C "$repo_dir" rev-parse --short HEAD 2>/dev/null || true)"
  [[ -n "$branch_name" ]] || return 1
  printf 'detached@%s\n' "$branch_name"
}

current_repo_origin_status() {
  local repo_dir="$1"
  local current_origin_url=""
  local managed_https_url=""
  local managed_ssh_url=""

  current_origin_url="$(git -C "$repo_dir" remote get-url origin 2>/dev/null || true)"
  managed_https_url="$(managed_repo_expected_https_origin_url "$repo_dir" 2>/dev/null || true)"
  managed_ssh_url="$(managed_repo_expected_ssh_origin_url "$repo_dir" 2>/dev/null || true)"

  if [[ -z "$current_origin_url" ]]; then
    printf '%s\n' "ausente"
    return 0
  fi

  if [[ "$current_origin_url" == "$REPO_SSH_URL" || ( -n "$managed_ssh_url" && "$current_origin_url" == "$managed_ssh_url" ) ]]; then
    printf '%s\n' "ssh"
    return 0
  fi

  if [[ "$current_origin_url" == "$REPO_HTTPS_URL" || ( -n "$managed_https_url" && "$current_origin_url" == "$managed_https_url" ) ]]; then
    printf '%s\n' "https"
    return 0
  fi

  printf '%s\n' "personalizado"
}

current_repo_commit_short() {
  local repo_dir="$1"
  local commit_hash=""

  commit_hash="$(git -C "$repo_dir" rev-parse --short HEAD 2>/dev/null || true)"
  [[ -n "$commit_hash" ]] || {
    printf '%s\n' "indisponível"
    return 0
  }

  printf '%s\n' "$commit_hash"
}

legacy_install_dir_path() {
  printf '%s\n' "$REPOSITORIES_DIR/arch-postinstall-apps"
}

managed_repo_expected_https_origin_url() {
  case "$1" in
    "$INSTALL_DIR")
      printf '%s\n' "$REPO_HTTPS_URL"
      ;;
    "$EASY_EFFECTS_PRESET_DIR")
      printf '%s\n' "$EASY_EFFECTS_PRESET_REPO_HTTPS_URL"
      ;;
    "$TERMINAL_LYRICS_DIR")
      printf '%s\n' "$TERMINAL_LYRICS_REPO_HTTPS_URL"
      ;;
    "$SYNTHETIC_PROFILE_GENERATOR_DIR")
      printf '%s\n' "$SYNTHETIC_PROFILE_GENERATOR_REPO_HTTPS_URL"
      ;;
    "$OBSLOVE_DOTS_DIR")
      printf '%s\n' "$OBSLOVE_DOTS_REPO_HTTPS_URL"
      ;;
    *)
      return 1
      ;;
  esac
}

managed_repo_expected_ssh_origin_url() {
  case "$1" in
    "$INSTALL_DIR")
      printf '%s\n' "$REPO_SSH_URL"
      ;;
    "$EASY_EFFECTS_PRESET_DIR")
      printf '%s\n' "$EASY_EFFECTS_PRESET_REPO_SSH_URL"
      ;;
    "$TERMINAL_LYRICS_DIR")
      printf '%s\n' "$TERMINAL_LYRICS_REPO_SSH_URL"
      ;;
    "$SYNTHETIC_PROFILE_GENERATOR_DIR")
      printf '%s\n' "$SYNTHETIC_PROFILE_GENERATOR_REPO_SSH_URL"
      ;;
    "$OBSLOVE_DOTS_DIR")
      printf '%s\n' "$OBSLOVE_DOTS_REPO_SSH_URL"
      ;;
    *)
      return 1
      ;;
  esac
}

managed_environment_repo_dirs() {
  printf '%s\n' \
    "$EASY_EFFECTS_PRESET_DIR" \
    "$TERMINAL_LYRICS_DIR" \
    "$SYNTHETIC_PROFILE_GENERATOR_DIR" \
    "$OBSLOVE_DOTS_DIR"
}

managed_repo_display_name() {
  case "$1" in
    "$INSTALL_DIR")
      printf '%s\n' "arch-postinstall-apps"
      ;;
    "$EASY_EFFECTS_PRESET_DIR")
      printf '%s\n' "EasyEffects-Preset"
      ;;
    "$TERMINAL_LYRICS_DIR")
      printf '%s\n' "terminal-lyrics"
      ;;
    "$SYNTHETIC_PROFILE_GENERATOR_DIR")
      printf '%s\n' "synthetic-profile-generator"
      ;;
    "$OBSLOVE_DOTS_DIR")
      printf '%s\n' "obslove"
      ;;
    *)
      basename "$1"
      ;;
  esac
}

managed_repo_origin_matches_expected() {
  local repo_dir="$1"
  local current_origin_url=""
  local expected_https_url=""
  local expected_ssh_url=""

  current_origin_url="$(git -C "$repo_dir" remote get-url origin 2>/dev/null || true)"
  expected_https_url="$(managed_repo_expected_https_origin_url "$repo_dir" 2>/dev/null || true)"
  expected_ssh_url="$(managed_repo_expected_ssh_origin_url "$repo_dir" 2>/dev/null || true)"
  [[ -n "$current_origin_url" && -n "$expected_https_url" && -n "$expected_ssh_url" ]] || return 1

  [[ "$current_origin_url" == "$expected_https_url" || "$current_origin_url" == "$expected_ssh_url" ]]
}

git_ssh_transport_ready() {
  local repo_url="$1"

  [[ -n "$repo_url" ]] || return 1
  command -v git >/dev/null 2>&1 || return 1

  GIT_SSH_COMMAND='ssh -o BatchMode=yes -o StrictHostKeyChecking=accept-new' \
    git ls-remote "$repo_url" HEAD >/dev/null 2>&1
}

managed_repo_preferred_origin_url() {
  local repo_dir="$1"
  local https_url=""
  local ssh_url=""

  https_url="$(managed_repo_expected_https_origin_url "$repo_dir" 2>/dev/null || true)"
  ssh_url="$(managed_repo_expected_ssh_origin_url "$repo_dir" 2>/dev/null || true)"
  [[ -n "$https_url" && -n "$ssh_url" ]] || return 1

  if github_ssh_expected && git_ssh_transport_ready "$ssh_url"; then
    printf '%s\n' "$ssh_url"
    return 0
  fi

  printf '%s\n' "$https_url"
}

ensure_managed_repo_origin_remote() {
  local repo_dir="$1"
  local desired_origin_url=""

  desired_origin_url="$(managed_repo_preferred_origin_url "$repo_dir" 2>/dev/null || true)"
  [[ -n "$desired_origin_url" ]] || return 1

  ensure_repo_origin_remote "$repo_dir" "$desired_origin_url"
}

ensure_managed_repo_origin_ssh() {
  local repo_dir="$1"
  local desired_origin_url=""

  desired_origin_url="$(managed_repo_expected_ssh_origin_url "$repo_dir" 2>/dev/null || true)"
  [[ -n "$desired_origin_url" ]] || return 1

  ensure_repo_origin_remote "$repo_dir" "$desired_origin_url"
}

reconcile_managed_repo_origin_ssh() {
  local repo_dir="$1"

  [[ -d "$repo_dir/.git" ]] || return 2

  if ! managed_repo_origin_matches_expected "$repo_dir"; then
    announce_detail "Foi detectado um remoto origin personalizado em $repo_dir. A configuração atual será mantida."
    return 2
  fi

  if ! ensure_managed_repo_origin_ssh "$repo_dir"; then
    return 1
  fi

  return 0
}

relocate_managed_install_repo() {
  local legacy_install_dir=""

  legacy_install_dir="$(legacy_install_dir_path)"
  [[ "$legacy_install_dir" != "$INSTALL_DIR" ]] || return 3
  [[ -d "$legacy_install_dir" ]] || return 2

  if [[ -e "$INSTALL_DIR" ]]; then
    announce_warning "O clone gerenciado legado em $legacy_install_dir não foi movido porque $INSTALL_DIR já existe."
    return 2
  fi

  if [[ ! -d "$legacy_install_dir/.git" ]]; then
    announce_warning "$legacy_install_dir existe, mas não é um repositório git gerenciado."
    return 2
  fi

  mkdir -p "$(dirname "$INSTALL_DIR")"
  announce_detail "Movendo clone gerenciado para $INSTALL_DIR..."
  if mv "$legacy_install_dir" "$INSTALL_DIR"; then
    return 0
  fi

  announce_warning "Não foi possível mover o clone gerenciado para $INSTALL_DIR."
  return 1
}

directory_is_git_repository() {
  local dir_path="$1"

  git -C "$dir_path" rev-parse --is-inside-work-tree >/dev/null 2>&1
}

home_repo_relocation_allowed() {
  local repo_dir="$1"
  local repo_name=""

  repo_name="$(basename "$repo_dir")"
  case "$repo_name" in
    Backups|Codex|Dots|EasyEffects-Preset|Pictures|Projects|Repositories|Videos)
      return 1
      ;;
  esac

  return 0
}

collect_loose_home_git_repositories() {
  local array_name="$1"
  local candidate
  local nullglob_was_enabled=0
  # shellcheck disable=SC2178
  declare -n target_repositories="$array_name"

  target_repositories=()

  if shopt -q nullglob; then
    nullglob_was_enabled=1
  fi
  shopt -s nullglob

  for candidate in "$HOME"/*; do
    [[ -d "$candidate" && ! -L "$candidate" ]] || continue
    home_repo_relocation_allowed "$candidate" || continue
    directory_is_git_repository "$candidate" || continue
    target_repositories+=("$candidate")
  done

  if [[ "$nullglob_was_enabled" != "1" ]]; then
    shopt -u nullglob
  fi
}

relocate_loose_home_git_repository() {
  local source_repo_dir="$1"
  local repo_name=""
  local target_repo_dir=""

  repo_name="$(basename "$source_repo_dir")"
  target_repo_dir="$REPOSITORIES_DIR/$repo_name"

  if [[ -e "$target_repo_dir" ]]; then
    announce_warning "O repositório '$repo_name' em $HOME não foi movido porque $target_repo_dir já existe."
    return 2
  fi

  announce_detail "Movendo repositório git para $target_repo_dir..."
  if mv "$source_repo_dir" "$target_repo_dir"; then
    return 0
  fi

  announce_warning "Não foi possível mover o repositório '$repo_name' para $target_repo_dir."
  return 1
}

managed_repo_is_dirty() {
  local repo_dir="$1"

  ! git -C "$repo_dir" diff --quiet --no-ext-diff || \
    ! git -C "$repo_dir" diff --cached --quiet --no-ext-diff || \
    [[ -n "$(git -C "$repo_dir" status --porcelain --untracked-files=normal)" ]]
}

easyeffects_preset_origin_matches() {
  managed_repo_origin_matches_expected "$EASY_EFFECTS_PRESET_DIR"
}

sync_managed_repo() {
  local repo_dir="$1"
  local repo_label=""
  local previous_commit=""
  local current_commit=""
  local clone_origin_url=""
  local label_suffix=""

  repo_label="$(managed_repo_display_name "$repo_dir")"
  label_suffix="do repositório $repo_label"

  if ! command -v git >/dev/null 2>&1; then
    announce_warning "O git não está disponível para sincronizar $label_suffix."
    return 1
  fi

  if [[ -d "$repo_dir/.git" ]]; then
    previous_commit="$(git -C "$repo_dir" rev-parse HEAD 2>/dev/null || true)"

    if ! managed_repo_origin_matches_expected "$repo_dir"; then
      announce_warning "O diretório $repo_dir já é um repositório git com origin diferente. A sincronização será ignorada."
      return 2
    fi

    if managed_repo_is_dirty "$repo_dir"; then
      announce_warning "O repositório em $repo_dir tem alterações locais. A atualização automática será ignorada."
      return 2
    fi

    if ! ensure_managed_repo_origin_remote "$repo_dir"; then
      announce_warning "Não foi possível ajustar o remoto de $label_suffix."
      return 1
    fi

    announce_detail "Atualizando $label_suffix..."
    if ! retry_log_only git -C "$repo_dir" fetch origin; then
      announce_warning "Não foi possível buscar atualizações de $label_suffix."
      return 1
    fi

    if git -C "$repo_dir" show-ref --verify --quiet "refs/heads/main"; then
      if ! run_log_only git -C "$repo_dir" checkout main; then
        announce_warning "Não foi possível trocar $label_suffix para a branch 'main'."
        return 1
      fi
    elif git -C "$repo_dir" show-ref --verify --quiet "refs/remotes/origin/main"; then
      if ! run_log_only git -C "$repo_dir" checkout -b main origin/main; then
        announce_warning "Não foi possível criar a branch local 'main' de $label_suffix."
        return 1
      fi
    else
      announce_warning "A branch 'main' não foi encontrada em $label_suffix."
      return 1
    fi

    if ! retry_log_only git -C "$repo_dir" pull --ff-only origin main; then
      announce_warning "Não foi possível atualizar $label_suffix com 'git pull --ff-only'."
      return 1
    fi

    current_commit="$(git -C "$repo_dir" rev-parse HEAD 2>/dev/null || true)"
    if [[ -n "$previous_commit" && "$previous_commit" == "$current_commit" ]]; then
      return 3
    fi

    return 0
  fi

  if [[ -e "$repo_dir" && -n "$(find "$repo_dir" -mindepth 1 -maxdepth 1 2>/dev/null)" ]]; then
    announce_warning "$repo_dir já existe e não está vazio. O clone de $label_suffix será ignorado."
    return 2
  fi

  announce_detail "Clonando $label_suffix em $repo_dir..."
  clone_origin_url="$(managed_repo_preferred_origin_url "$repo_dir" 2>/dev/null || true)"
  if [[ -z "$clone_origin_url" ]]; then
    announce_warning "Não foi possível definir a URL de clone de $label_suffix."
    return 1
  fi

  if ops_git_clone_main "$clone_origin_url" "$repo_dir"; then
    return 0
  fi

  announce_warning "Não foi possível clonar $label_suffix."
  return 1
}

sync_easyeffects_preset_repo() {
  sync_managed_repo "$EASY_EFFECTS_PRESET_DIR"
}

sync_terminal_lyrics_repo() {
  sync_managed_repo "$TERMINAL_LYRICS_DIR"
}

sync_synthetic_profile_generator_repo() {
  sync_managed_repo "$SYNTHETIC_PROFILE_GENERATOR_DIR"
}

sync_obslove_dots_repo() {
  sync_managed_repo "$OBSLOVE_DOTS_DIR"
}
