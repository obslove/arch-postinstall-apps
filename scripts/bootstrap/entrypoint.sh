# shellcheck shell=bash
# shellcheck disable=SC2034

SELF_PATH="${BASH_SOURCE[0]:-$0}"
SCRIPT_DIR="$(cd "$(dirname "$SELF_PATH")" && pwd)"
LOCAL_MAIN="$SCRIPT_DIR/scripts/install/main.sh"

if [[ -f "$SELF_PATH" && -f "$LOCAL_MAIN" ]]; then
  exec bash "$LOCAL_MAIN" "$@"
fi

REPO_HTTPS_URL="https://github.com/obslove/arch-postinstall-apps.git"
REPO_SSH_URL="git@github.com:obslove/arch-postinstall-apps.git"
REPOSITORIES_DIR="${REPOSITORIES_DIR:-$HOME/Repositories}"
INSTALL_DIR="${BOOTSTRAP_DIR:-$REPOSITORIES_DIR/arch-postinstall-apps}"
YAY_REPO_DIR="${YAY_REPO_DIR:-$REPOSITORIES_DIR/yay}"
YAY_SNAPSHOT_URL="${YAY_SNAPSHOT_URL:-https://aur.archlinux.org/cgit/aur.git/snapshot/yay.tar.gz}"
SSH_KEY_PATH="${SSH_KEY_PATH:-$HOME/.ssh/id_ed25519}"
GITHUB_SSH_KEY_NAME=""
LOG_FILE="${POSTINSTALL_LOG_FILE:-$HOME/Backups/arch-postinstall.log}"
SUMMARY_FILE="${POSTINSTALL_SUMMARY_FILE:-$HOME/Backups/arch-postinstall-summary.txt}"
CHECK_ONLY=0
EXCLUSIVE_GITHUB_SSH_KEY=0
SKIP_GITHUB_SSH=0
STEP_OUTPUT_ONLY=1
STATE_DIR="${POSTINSTALL_STATE_DIR:-${XDG_STATE_HOME:-$HOME/.local/state}/arch-postinstall-apps}"
LOCK_DIR="${POSTINSTALL_LOCK_DIR:-$STATE_DIR/lock}"
LOCK_HELD="${POSTINSTALL_LOCK_HELD:-0}"
BOOTSTRAP_PACKAGES=(
  ca-certificates
  git
  curl
  tar
)

cleanup_paths=()
step_counter=0
step_open=0
step_total=0
STEP_RESULT_STATUS=""
STEP_RESULT_MESSAGE=""

init_output_styles

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

    if ! ensure_repo_origin_remote "$INSTALL_DIR"; then
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

handle_bootstrap_step_result_or_exit() {
  case "${STEP_RESULT_STATUS:-}" in
    success|skipped|"")
      return 0
      ;;
    hard_fail)
      if [[ -n "${STEP_RESULT_MESSAGE:-}" ]]; then
        announce_error "$STEP_RESULT_MESSAGE"
      fi
      exit 1
      ;;
    *)
      announce_error "Resultado de etapa desconhecido no bootstrap: ${STEP_RESULT_STATUS:-indefinido}"
      exit 1
      ;;
  esac
}

bootstrap_install_dependencies_step() {
  local array_name="$1"
  # shellcheck disable=SC2178
  declare -n missing_packages="$array_name"

  step_result_reset

  if ((${#missing_packages[@]} == 0)); then
    announce_detail "As dependências iniciais já estão disponíveis. Etapa ignorada."
    step_result_skipped "As dependências iniciais já estavam disponíveis."
    return 0
  fi

  if retry_interactive_log_only sudo pacman -Syu --needed --noconfirm "${missing_packages[@]}"; then
    step_result_success "As dependências iniciais foram instaladas."
    return 0
  fi

  step_result_hard_fail "Não foi possível instalar as dependências iniciais."
}

bootstrap_sync_repo_step() {
  step_result_reset

  if sync_repo; then
    step_result_success "O repositório gerenciado foi sincronizado."
    return 0
  fi

  step_result_hard_fail "Não foi possível sincronizar o repositório gerenciado."
}

main() {
  local bootstrap_system_updated=0
  local bootstrap_missing_packages=()

  parse_cli_args "$@"
  trap cleanup EXIT

  ensure_not_root
  acquire_lock
  collect_missing_packages bootstrap_missing_packages "${BOOTSTRAP_PACKAGES[@]}"
  if ((${#bootstrap_missing_packages[@]} > 0)); then
    set_step_total 4
  else
    set_step_total 3
  fi

  announce_step "Validando ambiente..."
  ensure_arch
  ensure_supported_session
  require_command pacman
  require_command sudo
  announce_prompt "Autenticando sudo..."
  run_with_terminal_stdin sudo -v
  init_logging

  announce_step "Verificando dependências iniciais já instaladas..."
  if ((${#bootstrap_missing_packages[@]} > 0)); then
    announce_step "Instalando dependências iniciais..."
    bootstrap_install_dependencies_step bootstrap_missing_packages
    handle_bootstrap_step_result_or_exit
    bootstrap_system_updated=1
  fi

  require_command git
  require_command curl
  require_command tar
  bootstrap_sync_repo_step
  handle_bootstrap_step_result_or_exit

  exec env \
    POSTINSTALL_BOOTSTRAP_UPDATED="$bootstrap_system_updated" \
    POSTINSTALL_LOG_FILE="$LOG_FILE" \
    POSTINSTALL_LOG_INITIALIZED=1 \
    POSTINSTALL_LOCK_HELD=1 \
    POSTINSTALL_SUMMARY_FILE="$SUMMARY_FILE" \
    POSTINSTALL_STATE_DIR="$STATE_DIR" \
    POSTINSTALL_LOCK_DIR="$LOCK_DIR" \
    SSH_KEY_PATH="$SSH_KEY_PATH" \
    REPOSITORIES_DIR="$REPOSITORIES_DIR" \
    YAY_REPO_DIR="$YAY_REPO_DIR" \
    YAY_SNAPSHOT_URL="$YAY_SNAPSHOT_URL" \
    bash "$INSTALL_DIR/scripts/install/main.sh" "$@"
}

main "$@"
