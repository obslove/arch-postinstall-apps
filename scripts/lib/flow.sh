#!/usr/bin/env bash
# shellcheck shell=bash
# shellcheck source-path=SCRIPTDIR
# shellcheck source=scripts/lib/shellcheck-runtime.sh
# shellcheck source=scripts/lib/ops.sh
# shellcheck source=scripts/lib/status.sh
# shellcheck source=scripts/lib/components.sh
# shellcheck source=scripts/lib/runtime-state.sh
# shellcheck source=scripts/lib/summary.sh
# shellcheck source=scripts/lib/pipeline.sh
# shellcheck source=scripts/lib/steps/system.sh
# shellcheck source=scripts/lib/steps/packages.sh
# shellcheck source=scripts/lib/steps/desktop.sh
# shellcheck source=scripts/lib/steps/github-ssh.sh
# shellcheck source=scripts/lib/steps/verification.sh

if false; then
  source "$SCRIPT_DIR/scripts/lib/shellcheck-runtime.sh"
  source "$SCRIPT_DIR/scripts/lib/ops.sh"
  source "$SCRIPT_DIR/scripts/lib/status.sh"
  source "$SCRIPT_DIR/scripts/lib/components.sh"
  source "$SCRIPT_DIR/scripts/lib/runtime-state.sh"
  source "$SCRIPT_DIR/scripts/lib/summary.sh"
  source "$SCRIPT_DIR/scripts/lib/pipeline.sh"
  source "$SCRIPT_DIR/scripts/lib/steps/system.sh"
  source "$SCRIPT_DIR/scripts/lib/steps/packages.sh"
  source "$SCRIPT_DIR/scripts/lib/steps/desktop.sh"
  source "$SCRIPT_DIR/scripts/lib/steps/github-ssh.sh"
  source "$SCRIPT_DIR/scripts/lib/steps/verification.sh"
fi

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

define_runtime_pipeline() {
  local array_name="$1"
  local pre_package_component_ids=()
  local post_package_component_ids=()
  local component_id
  local pipeline_function

  pipeline_reset
  pipeline_add_step "load_configuration" "all" "pipeline_load_configuration_step" "$array_name"

  if [[ "$CHECK_ONLY" == "1" ]]; then
    pipeline_add_step "check_only_verification" "check" "pipeline_check_only_step" "$array_name"
    return 0
  fi

  pipeline_add_step "create_directories" "install" "pipeline_create_directories_step"
  pipeline_add_step "ensure_multilib" "install" "pipeline_ensure_multilib_step"
  pipeline_add_step "update_system" "install" "pipeline_update_system_step"
  pipeline_add_step "install_local_support_packages" "install" "pipeline_install_local_support_packages_step"
  mapfile -t pre_package_component_ids < <(component_pre_package_pipeline_ids)
  for component_id in "${pre_package_component_ids[@]}"; do
    pipeline_function="$(component_pipeline_step_function "$component_id")"
    pipeline_add_step "$component_id" "install" "$pipeline_function"
  done
  pipeline_add_step "install_packages" "install" "pipeline_install_packages_step" "$array_name"
  mapfile -t post_package_component_ids < <(component_post_package_pipeline_ids)
  for component_id in "${post_package_component_ids[@]}"; do
    pipeline_function="$(component_pipeline_step_function "$component_id")"
    pipeline_add_step "$component_id" "install" "$pipeline_function"
  done
  pipeline_add_step "final_verification" "install" "pipeline_final_verification_step" "$array_name"
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
  run_pipeline_steps "$execution_mode"

  if [[ "$execution_mode" == "install" ]]; then
    print_summary
  fi
}
