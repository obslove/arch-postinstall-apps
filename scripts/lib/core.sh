#!/usr/bin/env bash
# shellcheck shell=bash
# shellcheck disable=SC2034
# shellcheck source-path=SCRIPTDIR
# shellcheck source=scripts/lib/status.sh
# shellcheck source=scripts/lib/runtime-config.sh
# shellcheck source=scripts/lib/runtime-state.sh
# shellcheck source=scripts/lib/execution-report.sh
# shellcheck source=scripts/lib/step-result.sh
# shellcheck source=scripts/lib/ui.sh
# shellcheck source=scripts/lib/process.sh
# shellcheck source=scripts/lib/locking.sh
# shellcheck source=scripts/lib/env.sh

SHARED_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
# shellcheck source=runtime-config.sh
source "$SHARED_LIB_DIR/runtime-config.sh"
# shellcheck source=runtime-state.sh
source "$SHARED_LIB_DIR/runtime-state.sh"
# shellcheck source=execution-report.sh
source "$SHARED_LIB_DIR/execution-report.sh"
# shellcheck source=step-result.sh
source "$SHARED_LIB_DIR/step-result.sh"
# shellcheck source=ui.sh
source "$SHARED_LIB_DIR/ui.sh"
# shellcheck source=process.sh
source "$SHARED_LIB_DIR/process.sh"
# shellcheck source=locking.sh
source "$SHARED_LIB_DIR/locking.sh"
# shellcheck source=env.sh
source "$SHARED_LIB_DIR/env.sh"
# shellcheck source=cli.sh
source "$SHARED_LIB_DIR/cli.sh"
# shellcheck source=status.sh
source "$SHARED_LIB_DIR/status.sh"
COMPONENT_CONFIG_FILE="$(cd "$SHARED_LIB_DIR/../../config" && pwd)/components.sh"
# shellcheck source=../../config/components.sh
source "$COMPONENT_CONFIG_FILE"

execution_state_reset() {
  runtime_state_reset
  execution_report_reset
  step_result_reset
}

runtime_state_init() {
  cleanup_paths=()
  step_counter=0
  step_open=0
  step_total=0
  init_output_styles
  execution_state_reset

  if [[ "$SYSTEM_UPDATED" == "1" ]]; then
    report_mark_change "bootstrap_system_update"
  fi
}

record_soft_failure() {
  local message="$1"

  [[ -n "$message" ]] || return 0
  state_add_soft_failure "$message"
}

create_directories() {
  local target_dir
  local created_any=0
  local target_dirs=(
    "$HOME/Backups"
    "$HOME/Codex"
    "$HOME/Dots"
    "$HOME/Pictures/Screenshots"
    "$HOME/Pictures/Wallpapers"
    "$HOME/Projects"
    "$REPOSITORIES_DIR"
    "$HOME/Videos"
  )

  for target_dir in "${target_dirs[@]}"; do
    if [[ ! -d "$target_dir" ]]; then
      created_any=1
      break
    fi
  done

  mkdir -p \
    "${target_dirs[@]}"

  if [[ "$created_any" == "1" ]]; then
    report_mark_change "directories"
  fi
}
