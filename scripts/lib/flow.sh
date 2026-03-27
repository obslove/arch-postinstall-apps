#!/usr/bin/env bash
# shellcheck shell=bash
# shellcheck source-path=SCRIPTDIR
# shellcheck source=scripts/lib/ops.sh
# shellcheck source=scripts/lib/status.sh
# shellcheck source=scripts/lib/components.sh
# shellcheck source=scripts/lib/runtime-state.sh
# shellcheck source=scripts/lib/summary.sh
# shellcheck source=scripts/lib/pipeline.sh
# shellcheck source=scripts/lib/step-manifest.sh

handle_runtime_step_result_or_exit() {
  case "${STEP_RESULT_STATUS:-}" in
    success|"")
      return 0
      ;;
    skipped)
      return 0
      ;;
    soft_fail)
      record_soft_failure "$STEP_RESULT_MESSAGE"
      return 0
      ;;
    hard_fail)
      if [[ -n "${STEP_RESULT_MESSAGE:-}" ]]; then
        announce_error "$STEP_RESULT_MESSAGE"
      fi
      if [[ "${STEP_RESULT_SUMMARY_PRINTED:-0}" != "1" ]]; then
        print_summary
      fi
      exit 1
      ;;
    *)
      announce_error "Resultado de etapa desconhecido: ${STEP_RESULT_STATUS:-indefinido}"
      if [[ "${STEP_RESULT_SUMMARY_PRINTED:-0}" != "1" ]]; then
        print_summary
      fi
      exit 1
      ;;
  esac
}

run_install() {
  local execution_mode="install"
  # shellcheck disable=SC2034
  local package_list=()

  if [[ "$CHECK_ONLY" == "1" ]]; then
    execution_mode="check"
  fi

  execution_state_reset
  define_runtime_pipeline package_list

  if [[ "$execution_mode" == "check" ]]; then
    set_step_total "$(pipeline_count_steps_for_mode check)"
  fi

  run_pipeline_steps "$execution_mode" "handle_runtime_step_result_or_exit"

  if [[ "$execution_mode" == "install" ]]; then
    print_summary
  fi
}
