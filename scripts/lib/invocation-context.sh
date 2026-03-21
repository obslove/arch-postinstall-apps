#!/usr/bin/env bash
# shellcheck shell=bash

load_bootstrap_invocation_context() {
  config_init_bootstrap
  parse_cli_args "$@"
  config_finalize
}

load_runtime_invocation_context() {
  local repo_dir="$1"
  shift

  config_init_runtime "$repo_dir"
  parse_cli_args "$@"
  config_finalize
}

append_runtime_invocation_env() {
  local array_name="$1"
  # shellcheck disable=SC2178
  declare -n env_assignments="$array_name"

  env_assignments+=(
    "POSTINSTALL_BOOTSTRAP_UPDATED=$BOOTSTRAP_SYSTEM_UPDATED"
    "POSTINSTALL_LOG_FILE=$LOG_FILE"
    "POSTINSTALL_LOG_INITIALIZED=1"
    "POSTINSTALL_LOCK_HELD=1"
    "POSTINSTALL_SUMMARY_FILE=$SUMMARY_FILE"
    "POSTINSTALL_STATE_DIR=$STATE_DIR"
    "POSTINSTALL_LOCK_DIR=$LOCK_DIR"
    "POSTINSTALL_SSH_KEY_PATH=$SSH_KEY_PATH"
    "POSTINSTALL_REPOSITORIES_DIR=$REPOSITORIES_DIR"
    "POSTINSTALL_YAY_REPO_DIR=$YAY_REPO_DIR"
    "POSTINSTALL_YAY_SNAPSHOT_URL=$YAY_SNAPSHOT_URL"
    "POSTINSTALL_CHECK_ONLY=$CHECK_ONLY"
    "POSTINSTALL_EXCLUSIVE_GITHUB_SSH_KEY=$EXCLUSIVE_GITHUB_SSH_KEY"
    "POSTINSTALL_SKIP_GITHUB_SSH=$SKIP_GITHUB_SSH"
    "POSTINSTALL_GITHUB_SSH_KEY_NAME=$GITHUB_SSH_KEY_NAME"
    "POSTINSTALL_STEP_OUTPUT_ONLY=$STEP_OUTPUT_ONLY"
  )
}

exec_runtime_with_invocation_context() {
  local runtime_entrypoint="$1"
  local env_assignments=()

  append_runtime_invocation_env env_assignments
  exec env "${env_assignments[@]}" bash "$runtime_entrypoint"
}
