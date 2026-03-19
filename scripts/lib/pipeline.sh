#!/usr/bin/env bash
# shellcheck shell=bash

PIPELINE_STEP_IDS=()
PIPELINE_STEP_MODES=()
PIPELINE_STEP_FUNCTIONS=()
PIPELINE_STEP_ARGS=()

pipeline_reset() {
  PIPELINE_STEP_IDS=()
  PIPELINE_STEP_MODES=()
  PIPELINE_STEP_FUNCTIONS=()
  PIPELINE_STEP_ARGS=()
}

pipeline_add_step() {
  local step_id="$1"
  local step_mode="$2"
  local step_function="$3"
  local step_args="${4:-}"

  PIPELINE_STEP_IDS+=("$step_id")
  PIPELINE_STEP_MODES+=("$step_mode")
  PIPELINE_STEP_FUNCTIONS+=("$step_function")
  PIPELINE_STEP_ARGS+=("$step_args")
}

pipeline_step_matches_mode() {
  local step_mode="$1"
  local execution_mode="$2"

  [[ "$step_mode" == "all" || "$step_mode" == "$execution_mode" ]]
}

run_pipeline_steps() {
  local execution_mode="$1"
  local index
  local step_function
  local step_args

  for index in "${!PIPELINE_STEP_IDS[@]}"; do
    if ! pipeline_step_matches_mode "${PIPELINE_STEP_MODES[$index]}" "$execution_mode"; then
      continue
    fi

    step_function="${PIPELINE_STEP_FUNCTIONS[$index]}"
    step_args="${PIPELINE_STEP_ARGS[$index]}"

    if [[ -n "$step_args" ]]; then
      "$step_function" "$step_args"
    else
      "$step_function"
    fi
  done
}
