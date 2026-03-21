# shellcheck shell=bash
# shellcheck disable=SC2034
# shellcheck source-path=SCRIPTDIR
# shellcheck source=scripts/lib/cli.sh
# shellcheck source=scripts/lib/runtime-config.sh
# shellcheck source=scripts/lib/step-result.sh
# shellcheck source=scripts/lib/ui.sh
# shellcheck source=scripts/lib/pipeline.sh
# shellcheck source=scripts/lib/step-manifest.sh
# shellcheck source=scripts/lib/process.sh
# shellcheck source=scripts/lib/locking.sh
# shellcheck source=scripts/lib/env.sh
# shellcheck source=scripts/lib/ops.sh
# shellcheck source=scripts/lib/repo.sh
# shellcheck source=scripts/bootstrap/repo-sync.sh

if false; then
  source "$SCRIPT_DIR/scripts/lib/cli.sh"
  source "$SCRIPT_DIR/scripts/lib/runtime-config.sh"
  source "$SCRIPT_DIR/scripts/lib/step-result.sh"
  source "$SCRIPT_DIR/scripts/lib/ui.sh"
  source "$SCRIPT_DIR/scripts/lib/pipeline.sh"
  source "$SCRIPT_DIR/scripts/lib/step-manifest.sh"
  source "$SCRIPT_DIR/scripts/lib/process.sh"
  source "$SCRIPT_DIR/scripts/lib/locking.sh"
  source "$SCRIPT_DIR/scripts/lib/env.sh"
  source "$SCRIPT_DIR/scripts/lib/ops.sh"
  source "$SCRIPT_DIR/scripts/lib/repo.sh"
  source "$SCRIPT_DIR/scripts/bootstrap/repo-sync.sh"
fi

SELF_PATH="${BASH_SOURCE[0]:-$0}"
BOOTSTRAP_SCRIPT_DIR="$(cd "$(dirname "$SELF_PATH")" && pwd)"
LOCAL_MAIN="$BOOTSTRAP_SCRIPT_DIR/scripts/install/main.sh"

if [[ -f "$SELF_PATH" && -f "$LOCAL_MAIN" ]]; then
  exec bash "$LOCAL_MAIN" "$@"
fi

config_init_bootstrap
BOOTSTRAP_PACKAGES=(
  ca-certificates
  git
  curl
  tar
)
BOOTSTRAP_MISSING_PACKAGES=()
BOOTSTRAP_SYSTEM_UPDATED=0

cleanup_paths=()
step_counter=0
step_open=0
step_total=0
STEP_RESULT_STATUS=""
STEP_RESULT_MESSAGE=""

init_output_styles

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

bootstrap_validate_environment_step() {
  step_result_reset

  if ! ensure_arch; then
    step_result_hard_fail "Este bootstrap só pode ser executado em Arch Linux."
    return 0
  fi

  if ! ensure_supported_session; then
    step_result_hard_fail "A sessão atual não é compatível com o bootstrap."
    return 0
  fi

  if ! require_command pacman; then
    step_result_hard_fail "O comando 'pacman' é obrigatório para continuar."
    return 0
  fi

  if ! require_command sudo; then
    step_result_hard_fail "O comando 'sudo' é obrigatório para continuar."
    return 0
  fi

  announce_prompt "Autenticando sudo..."
  if ! run_with_terminal_stdin sudo -v; then
    step_result_hard_fail "Não foi possível autenticar o sudo."
    return 0
  fi

  init_logging
  step_result_success "O ambiente de bootstrap foi validado."
}

bootstrap_check_dependencies_step() {
  local array_name="$1"
  # shellcheck disable=SC2178
  declare -n missing_packages="$array_name"

  step_result_reset

  if ((${#missing_packages[@]} == 0)); then
    announce_detail "As dependências iniciais já estão disponíveis."
    step_result_success "As dependências iniciais já estavam disponíveis."
    return 0
  fi

  announce_detail "${#missing_packages[@]} dependência(s) inicial(is) ainda não instalada(s)."
  step_result_success "As dependências iniciais foram avaliadas."
}

bootstrap_install_dependencies_step() {
  local array_name="${1:-BOOTSTRAP_MISSING_PACKAGES}"
  # shellcheck disable=SC2178
  declare -n missing_packages="$array_name"

  step_result_reset

  if ((${#missing_packages[@]} == 0)); then
    announce_detail "As dependências iniciais já estão disponíveis. Etapa ignorada."
    step_result_skipped "As dependências iniciais já estavam disponíveis."
    return 0
  fi

  if retry_interactive_log_only sudo pacman -Syu --needed --noconfirm "${missing_packages[@]}"; then
    BOOTSTRAP_SYSTEM_UPDATED=1
    step_result_success "As dependências iniciais foram instaladas."
    return 0
  fi

  step_result_hard_fail "Não foi possível instalar as dependências iniciais."
}

bootstrap_sync_repo_step() {
  step_result_reset

  if ! require_command git; then
    step_result_hard_fail "O comando 'git' é obrigatório para sincronizar o repositório."
    return 0
  fi

  if ! require_command curl; then
    step_result_hard_fail "O comando 'curl' é obrigatório para sincronizar o repositório."
    return 0
  fi

  if ! require_command tar; then
    step_result_hard_fail "O comando 'tar' é obrigatório para sincronizar o repositório."
    return 0
  fi

  if sync_repo; then
    step_result_success "O repositório gerenciado foi sincronizado."
    return 0
  fi

  step_result_hard_fail "Não foi possível sincronizar o repositório gerenciado."
}

main() {
  parse_cli_args "$@"
  validate_managed_paths
  trap cleanup EXIT

  ensure_not_root
  acquire_lock
  collect_missing_packages BOOTSTRAP_MISSING_PACKAGES "${BOOTSTRAP_PACKAGES[@]}"
  define_bootstrap_pipeline BOOTSTRAP_MISSING_PACKAGES
  set_step_total "$(pipeline_count_steps_for_mode bootstrap)"
  run_pipeline_steps "bootstrap" "handle_bootstrap_step_result_or_exit"

  exec env \
    POSTINSTALL_BOOTSTRAP_UPDATED="$BOOTSTRAP_SYSTEM_UPDATED" \
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
