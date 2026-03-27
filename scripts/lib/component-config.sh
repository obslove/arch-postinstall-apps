#!/usr/bin/env bash
# shellcheck shell=bash
# shellcheck disable=SC2034

COMPONENT_CONFIG_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")/../../config" && pwd)"
COMPONENT_CONFIG_FILE="$COMPONENT_CONFIG_DIR/components.sh"
# shellcheck source=../../config/components.sh
source "$COMPONENT_CONFIG_FILE"

config_array_contains() {
  local array_name="$1"
  local expected="$2"
  local item
  # shellcheck disable=SC2178
  declare -n target_array="$array_name"

  for item in "${target_array[@]}"; do
    [[ "$item" == "$expected" ]] && return 0
  done

  return 1
}

print_config_array() {
  local array_name="$1"
  # shellcheck disable=SC2178
  declare -n target_array="$array_name"

  printf '%s\n' "${target_array[@]}"
}

component_enabled() {
  config_array_contains ENABLED_SPECIAL_COMPONENTS "$1"
}

component_expected_always() {
  return 0
}

component_expected_codex_cli() {
  component_enabled "codex_cli"
}
