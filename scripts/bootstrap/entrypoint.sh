# shellcheck shell=bash
# shellcheck disable=SC2034
# shellcheck source-path=SCRIPTDIR
SELF_PATH="${BASH_SOURCE[0]:-$0}"
BOOTSTRAP_SCRIPT_DIR="$(cd "$(dirname "$SELF_PATH")" && pwd)"

resolve_local_main() {
  local candidate=""

  for candidate in \
    "$BOOTSTRAP_SCRIPT_DIR/scripts/install/main.sh" \
    "$BOOTSTRAP_SCRIPT_DIR/../scripts/install/main.sh"; do
    if [[ -f "$candidate" ]]; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done

  return 1
}

LOCAL_MAIN="$(resolve_local_main 2>/dev/null || true)"
if [[ -n "$LOCAL_MAIN" ]]; then
  exec bash "$LOCAL_MAIN" "$@"
fi

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

main() {
  load_bootstrap_invocation_context "$@"
  validate_managed_paths
  trap cleanup EXIT

  ensure_not_root
  acquire_lock
  collect_missing_packages BOOTSTRAP_MISSING_PACKAGES "${BOOTSTRAP_REMOTE_PACKAGES[@]}"
  define_bootstrap_pipeline BOOTSTRAP_MISSING_PACKAGES
  set_step_total "$(pipeline_count_steps_for_mode bootstrap)"
  run_pipeline_steps "bootstrap" "handle_bootstrap_step_result_or_exit"

  exec_runtime_with_invocation_context "$INSTALL_DIR/scripts/install/main.sh"
}

main "$@"
