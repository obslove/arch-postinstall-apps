#!/usr/bin/env bash
# shellcheck shell=bash

PIPELINE_STEP_IDS=()
PIPELINE_STEP_MODES=()
PIPELINE_STEP_TITLES=()
PIPELINE_STEP_FUNCTIONS=()
PIPELINE_STEP_COUNT_FLAGS=()
PIPELINE_STEP_ARGS=()

pipeline_reset() {
  PIPELINE_STEP_IDS=()
  PIPELINE_STEP_MODES=()
  PIPELINE_STEP_TITLES=()
  PIPELINE_STEP_FUNCTIONS=()
  PIPELINE_STEP_COUNT_FLAGS=()
  PIPELINE_STEP_ARGS=()
}

pipeline_add_step() {
  local step_id="$1"
  local step_mode="$2"
  local step_title="$3"
  local step_function="$4"
  local step_count_flag="${5:-1}"
  local step_args="${6:-}"

  PIPELINE_STEP_IDS+=("$step_id")
  PIPELINE_STEP_MODES+=("$step_mode")
  PIPELINE_STEP_TITLES+=("$step_title")
  PIPELINE_STEP_FUNCTIONS+=("$step_function")
  PIPELINE_STEP_COUNT_FLAGS+=("$step_count_flag")
  PIPELINE_STEP_ARGS+=("$step_args")
}

pipeline_step_matches_mode() {
  local step_mode="$1"
  local execution_mode="$2"

  [[ "$step_mode" == "all" || "$step_mode" == "$execution_mode" ]]
}

pipeline_contains_step_id() {
  local step_id="$1"
  local existing_id

  for existing_id in "${PIPELINE_STEP_IDS[@]}"; do
    [[ "$existing_id" == "$step_id" ]] && return 0
  done

  return 1
}

pipeline_count_steps_for_mode() {
  local execution_mode="$1"
  local total=0
  local index

  for index in "${!PIPELINE_STEP_IDS[@]}"; do
    if ! pipeline_step_matches_mode "${PIPELINE_STEP_MODES[$index]}" "$execution_mode"; then
      continue
    fi

    [[ "${PIPELINE_STEP_COUNT_FLAGS[$index]:-0}" == "1" ]] || continue
    total=$((total + 1))
  done

  printf '%s\n' "$total"
}

run_pipeline_steps() {
  local execution_mode="$1"
  local result_handler="${2:-}"
  local index=0
  local step_title
  local step_function
  local step_count_flag
  local step_args

  while (( index < ${#PIPELINE_STEP_IDS[@]} )); do
    if ! pipeline_step_matches_mode "${PIPELINE_STEP_MODES[$index]}" "$execution_mode"; then
      index=$((index + 1))
      continue
    fi

    step_title="${PIPELINE_STEP_TITLES[$index]}"
    step_function="${PIPELINE_STEP_FUNCTIONS[$index]}"
    step_count_flag="${PIPELINE_STEP_COUNT_FLAGS[$index]:-0}"
    step_args="${PIPELINE_STEP_ARGS[$index]}"

    if [[ "$step_count_flag" == "1" && -n "$step_title" ]]; then
      announce_step "$step_title"
    fi

    if [[ -n "$step_args" ]]; then
      "$step_function" "$step_args"
    else
      "$step_function"
    fi

    if [[ -n "$result_handler" ]]; then
      "$result_handler"
    fi

    index=$((index + 1))
  done
}
