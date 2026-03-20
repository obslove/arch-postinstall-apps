#!/usr/bin/env bash
# shellcheck shell=bash
# shellcheck disable=SC2034

STATE_MAIN_OFFICIAL_PACKAGES=()
STATE_MAIN_AUR_PACKAGES=()
STATE_FAILED_OFFICIAL_PACKAGES=()
STATE_FAILED_AUR_PACKAGES=()
STATE_SUPPORT_PACKAGES=()
STATE_ENVIRONMENT_PACKAGES=()
STATE_VERIFIED_ITEMS=()
STATE_MISSING_ITEMS=()
STATE_VERSION_LINES=()
STATE_SOFT_FAILURES=()
STATE_COMPONENT_STATUS_GITHUB_SSH=""
STATE_COMPONENT_STATUS_DESKTOP_INTEGRATION=""
STATE_AUR_HELPER_NAME=""
STATE_AUR_HELPER_STATUS=""
STATE_TEMP_CLIPBOARD_PACKAGE=""
STATE_OFFICIAL_REPO_METADATA_CHECKED=0
STATE_OFFICIAL_REPO_METADATA_READY=0

runtime_state_reset() {
  STATE_MAIN_OFFICIAL_PACKAGES=()
  STATE_MAIN_AUR_PACKAGES=()
  STATE_FAILED_OFFICIAL_PACKAGES=()
  STATE_FAILED_AUR_PACKAGES=()
  STATE_SUPPORT_PACKAGES=()
  STATE_ENVIRONMENT_PACKAGES=()
  STATE_VERIFIED_ITEMS=()
  STATE_MISSING_ITEMS=()
  STATE_VERSION_LINES=()
  STATE_SOFT_FAILURES=()
  STATE_COMPONENT_STATUS_GITHUB_SSH="$STATUS_PENDING"
  STATE_COMPONENT_STATUS_DESKTOP_INTEGRATION="$STATUS_PENDING"
  STATE_AUR_HELPER_NAME=""
  STATE_AUR_HELPER_STATUS="não preparado"
  STATE_TEMP_CLIPBOARD_PACKAGE=""
  STATE_OFFICIAL_REPO_METADATA_CHECKED=0
  STATE_OFFICIAL_REPO_METADATA_READY=0
}

state_reset_package_results() {
  STATE_MAIN_OFFICIAL_PACKAGES=()
  STATE_MAIN_AUR_PACKAGES=()
  STATE_FAILED_OFFICIAL_PACKAGES=()
  STATE_FAILED_AUR_PACKAGES=()
  STATE_SUPPORT_PACKAGES=()
  STATE_ENVIRONMENT_PACKAGES=()
}

state_reset_environment_packages() {
  STATE_ENVIRONMENT_PACKAGES=()
}

state_reset_verification_results() {
  STATE_VERIFIED_ITEMS=()
  STATE_MISSING_ITEMS=()
  STATE_VERSION_LINES=()
}

state_add_main_official_package() {
  append_array_item STATE_MAIN_OFFICIAL_PACKAGES "$1"
}

state_add_main_aur_package() {
  append_array_item STATE_MAIN_AUR_PACKAGES "$1"
}

state_add_official_failure() {
  append_array_item STATE_FAILED_OFFICIAL_PACKAGES "$1"
}

state_add_aur_failure() {
  append_array_item STATE_FAILED_AUR_PACKAGES "$1"
}

state_add_support_package() {
  append_array_item STATE_SUPPORT_PACKAGES "$1"
}

state_add_environment_package() {
  append_array_item STATE_ENVIRONMENT_PACKAGES "$1"
}

state_add_verified_item() {
  append_array_item STATE_VERIFIED_ITEMS "$1"
}

state_add_missing_item() {
  append_array_item STATE_MISSING_ITEMS "$1"
}

state_add_version_line() {
  append_array_item STATE_VERSION_LINES "$1"
}

state_add_soft_failure() {
  append_array_item STATE_SOFT_FAILURES "$1"
}

state_set_component_status() {
  local component_id="$1"
  local status_value="$2"

  case "$component_id" in
    github_ssh)
      STATE_COMPONENT_STATUS_GITHUB_SSH="$status_value"
      ;;
    desktop_integration)
      STATE_COMPONENT_STATUS_DESKTOP_INTEGRATION="$status_value"
      ;;
  esac
}

state_get_component_status() {
  local component_id="$1"

  case "$component_id" in
    github_ssh)
      printf '%s\n' "${STATE_COMPONENT_STATUS_GITHUB_SSH:-$STATUS_PENDING}"
      ;;
    desktop_integration)
      printf '%s\n' "${STATE_COMPONENT_STATUS_DESKTOP_INTEGRATION:-$STATUS_PENDING}"
      ;;
    *)
      printf '%s\n' ""
      ;;
  esac
}

state_set_aur_helper() {
  STATE_AUR_HELPER_NAME="$1"
  STATE_AUR_HELPER_STATUS="$2"
}

state_get_aur_helper_name() {
  printf '%s\n' "$STATE_AUR_HELPER_NAME"
}

state_get_aur_helper_status() {
  printf '%s\n' "${STATE_AUR_HELPER_STATUS:-indisponível}"
}

state_set_temp_clipboard_package() {
  STATE_TEMP_CLIPBOARD_PACKAGE="$1"
}

state_get_temp_clipboard_package() {
  printf '%s\n' "$STATE_TEMP_CLIPBOARD_PACKAGE"
}

state_official_repo_metadata_checked() {
  [[ "$STATE_OFFICIAL_REPO_METADATA_CHECKED" == "1" ]]
}

state_set_official_repo_metadata_checked() {
  STATE_OFFICIAL_REPO_METADATA_CHECKED=1
}

state_official_repo_metadata_ready() {
  [[ "$STATE_OFFICIAL_REPO_METADATA_READY" == "1" ]]
}

state_set_official_repo_metadata_ready() {
  STATE_OFFICIAL_REPO_METADATA_READY="$1"
}

state_has_package_failures() {
  (( ${#STATE_FAILED_OFFICIAL_PACKAGES[@]} > 0 || ${#STATE_FAILED_AUR_PACKAGES[@]} > 0 ))
}

state_has_missing_items() {
  (( ${#STATE_MISSING_ITEMS[@]} > 0 ))
}

state_has_verified_item() {
  local expected="$1"
  local item

  for item in "${STATE_VERIFIED_ITEMS[@]}"; do
    [[ "$item" == "$expected" ]] && return 0
  done

  return 1
}
