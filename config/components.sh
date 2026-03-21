#!/usr/bin/env bash
# shellcheck shell=bash
# shellcheck disable=SC2034

readonly -a ENABLED_SPECIAL_COMPONENTS=(
  codex_cli
)

readonly -a BOOTSTRAP_SUPPORT_PACKAGES=(
  git
  base-devel
)

readonly -a LOCAL_SUPPORT_PACKAGES=(
  shellcheck
)

readonly -a AUR_HELPER_SUPPORT_PACKAGES=(
  base-devel
)

readonly -a AUR_HELPER_README_ITEMS=(
  base-devel
  yay
)

readonly -a GITHUB_SSH_SUPPORT_PACKAGES=(
  github-cli
  openssh
)

readonly -a CODEX_CLI_PACKAGES=(
  nodejs
  npm
)

readonly -a CODEX_CLI_README_ITEMS=(
  nodejs
  npm
  codex
)

readonly -a DESKTOP_INTEGRATION_PACKAGES=(
  pipewire
  wireplumber
  xdg-utils
  xdg-desktop-portal
  xdg-desktop-portal-gtk
  xdg-desktop-portal-hyprland
)

readonly -a DESKTOP_USER_SERVICES=(
  pipewire.service
  wireplumber.service
  xdg-desktop-portal.service
)

readonly -a TEMPORARY_CLIPBOARD_PACKAGES=(
  wl-clipboard
)

COMPONENT_IDS=()
declare -Ag COMPONENT_LABELS=()
declare -Ag COMPONENT_PIPELINE_PHASES=()
declare -Ag COMPONENT_EXPECTED_FUNCTIONS=()
declare -Ag COMPONENT_PIPELINE_TITLES=()
declare -Ag COMPONENT_PIPELINE_STEP_FUNCTIONS=()
declare -Ag COMPONENT_SUMMARY_FORMATTERS=()
declare -Ag COMPONENT_RUNTIME_STATUS_FLAGS=()
declare -Ag COMPONENT_CHECKPOINT_FLAGS=()
declare -Ag COMPONENT_CHECK_ONLY_DETECTION_FLAGS=()
declare -Ag COMPONENT_VERIFICATION_FLAGS=()
declare -Ag COMPONENT_SUMMARY_STATUS_FLAGS=()

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

print_component_ids_by_property() {
  local property_name="$1"
  local expected_value="${2:-1}"
  local component_id
  # shellcheck disable=SC2178
  declare -n property_map="$property_name"

  for component_id in "${COMPONENT_IDS[@]}"; do
    [[ "${property_map[$component_id]:-}" == "$expected_value" ]] || continue
    printf '%s\n' "$component_id"
  done
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

register_component() {
  local component_id="$1"
  local component_label="$2"
  local pipeline_phase="$3"
  local expected_function="$4"
  local pipeline_title="$5"
  local pipeline_step_function="$6"
  local summary_formatter="$7"
  local has_runtime_status="$8"
  local has_checkpoint="$9"
  local check_only_detection="${10}"
  local verification_enabled="${11}"
  local summary_status_enabled="${12}"

  COMPONENT_IDS+=("$component_id")
  COMPONENT_LABELS["$component_id"]="$component_label"
  COMPONENT_PIPELINE_PHASES["$component_id"]="$pipeline_phase"
  COMPONENT_EXPECTED_FUNCTIONS["$component_id"]="$expected_function"
  COMPONENT_PIPELINE_TITLES["$component_id"]="$pipeline_title"
  COMPONENT_PIPELINE_STEP_FUNCTIONS["$component_id"]="$pipeline_step_function"
  COMPONENT_SUMMARY_FORMATTERS["$component_id"]="$summary_formatter"
  COMPONENT_RUNTIME_STATUS_FLAGS["$component_id"]="$has_runtime_status"
  COMPONENT_CHECKPOINT_FLAGS["$component_id"]="$has_checkpoint"
  COMPONENT_CHECK_ONLY_DETECTION_FLAGS["$component_id"]="$check_only_detection"
  COMPONENT_VERIFICATION_FLAGS["$component_id"]="$verification_enabled"
  COMPONENT_SUMMARY_STATUS_FLAGS["$component_id"]="$summary_status_enabled"
}

register_component \
  "aur_helper" \
  "Helper AUR" \
  "pre_package" \
  "component_expected_always" \
  "Preparando helper AUR..." \
  "prepare_aur_helper_step" \
  "state_get_aur_helper_status" \
  "0" \
  "0" \
  "1" \
  "1" \
  "1"

register_component \
  "codex_cli" \
  "Codex CLI" \
  "post_package" \
  "component_expected_codex_cli" \
  "Configurando Codex CLI..." \
  "codex_cli_step" \
  "" \
  "0" \
  "1" \
  "0" \
  "1" \
  "0"

register_component \
  "desktop_integration" \
  "Integração desktop" \
  "post_package" \
  "component_expected_always" \
  "Ajustando integração desktop..." \
  "desktop_integration_step" \
  "format_desktop_integration_status" \
  "1" \
  "1" \
  "1" \
  "1" \
  "1"

register_component \
  "github_ssh" \
  "GitHub SSH" \
  "post_package" \
  "github_ssh_expected" \
  "Configurando GitHub SSH..." \
  "github_ssh_step" \
  "format_github_ssh_status" \
  "1" \
  "1" \
  "1" \
  "1" \
  "1"

component_registry_ids() {
  print_config_array COMPONENT_IDS
}

component_pre_package_pipeline_ids() {
  print_component_ids_by_property COMPONENT_PIPELINE_PHASES "pre_package"
}

component_post_package_pipeline_ids() {
  print_component_ids_by_property COMPONENT_PIPELINE_PHASES "post_package"
}

component_check_only_detection_ids() {
  print_component_ids_by_property COMPONENT_CHECK_ONLY_DETECTION_FLAGS
}

component_verification_ids() {
  print_component_ids_by_property COMPONENT_VERIFICATION_FLAGS
}

component_summary_status_ids() {
  print_component_ids_by_property COMPONENT_SUMMARY_STATUS_FLAGS
}

component_checkpoint_summary_ids() {
  print_component_ids_by_property COMPONENT_CHECKPOINT_FLAGS
}

component_summary_label() {
  printf '%s\n' "${COMPONENT_LABELS[$1]:-$1}"
}

component_is_expected() {
  local expected_function="${COMPONENT_EXPECTED_FUNCTIONS[$1]:-}"

  [[ -n "$expected_function" ]] || return 1
  "$expected_function"
}

component_has_runtime_status() {
  [[ "${COMPONENT_RUNTIME_STATUS_FLAGS[$1]:-0}" == "1" ]]
}

component_pipeline_step_function() {
  local pipeline_step_function="${COMPONENT_PIPELINE_STEP_FUNCTIONS[$1]:-}"

  [[ -n "$pipeline_step_function" ]] || return 1
  printf '%s\n' "$pipeline_step_function"
}

component_pipeline_title() {
  local pipeline_title="${COMPONENT_PIPELINE_TITLES[$1]:-}"

  [[ -n "$pipeline_title" ]] || return 1
  printf '%s\n' "$pipeline_title"
}

component_summary_formatter_function() {
  local summary_formatter="${COMPONENT_SUMMARY_FORMATTERS[$1]:-}"

  [[ -n "$summary_formatter" ]] || return 1
  printf '%s\n' "$summary_formatter"
}
