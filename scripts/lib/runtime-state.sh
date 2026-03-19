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
