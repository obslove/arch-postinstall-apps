#!/usr/bin/env bash
# shellcheck shell=bash
# shellcheck disable=SC2034

STATE_MAIN_OFFICIAL_PACKAGES=()
STATE_MAIN_AUR_PACKAGES=()
STATE_FAILED_OFFICIAL_PACKAGES=()
STATE_FAILED_AUR_PACKAGES=()
STATE_VERIFIED_ITEM_IDS=()
STATE_VERIFIED_ITEMS=()
STATE_MISSING_ITEM_IDS=()
STATE_MISSING_ITEMS=()
declare -Ag STATE_VERIFICATION_LABELS=()
declare -Ag STATE_VERIFICATION_KINDS=()
declare -Ag STATE_VERIFICATION_REPAIR_STRATEGIES=()
declare -Ag STATE_VERIFICATION_TARGETS=()
declare -Ag STATE_VERIFICATION_STATUSES=()
STATE_VERSION_LINES=()
STATE_SOFT_FAILURES=()
declare -Ag STATE_COMPONENT_STATUSES=()
STATE_AUR_HELPER_NAME=""
STATE_AUR_HELPER_STATUS=""
STATE_TEMP_CLIPBOARD_PACKAGE=""
STATE_OFFICIAL_REPO_METADATA_CHECKED=0
STATE_OFFICIAL_REPO_METADATA_READY=0

runtime_state_reset() {
  local component_id

  STATE_MAIN_OFFICIAL_PACKAGES=()
  STATE_MAIN_AUR_PACKAGES=()
  STATE_FAILED_OFFICIAL_PACKAGES=()
  STATE_FAILED_AUR_PACKAGES=()
  STATE_VERIFIED_ITEM_IDS=()
  STATE_VERIFIED_ITEMS=()
  STATE_MISSING_ITEM_IDS=()
  STATE_MISSING_ITEMS=()
  STATE_VERIFICATION_LABELS=()
  STATE_VERIFICATION_KINDS=()
  STATE_VERIFICATION_REPAIR_STRATEGIES=()
  STATE_VERIFICATION_TARGETS=()
  STATE_VERIFICATION_STATUSES=()
  STATE_VERSION_LINES=()
  STATE_SOFT_FAILURES=()
  STATE_COMPONENT_STATUSES=()
  STATE_AUR_HELPER_NAME=""
  STATE_AUR_HELPER_STATUS="não preparado"
  STATE_TEMP_CLIPBOARD_PACKAGE=""
  STATE_OFFICIAL_REPO_METADATA_CHECKED=0
  STATE_OFFICIAL_REPO_METADATA_READY=0

  for component_id in "${COMPONENT_IDS[@]}"; do
    component_has_runtime_status "$component_id" || continue
    STATE_COMPONENT_STATUSES["$component_id"]="$STATUS_PENDING"
  done
}

state_reset_package_results() {
  STATE_MAIN_OFFICIAL_PACKAGES=()
  STATE_MAIN_AUR_PACKAGES=()
  STATE_FAILED_OFFICIAL_PACKAGES=()
  STATE_FAILED_AUR_PACKAGES=()
}

state_reset_verification_results() {
  STATE_VERIFIED_ITEM_IDS=()
  STATE_VERIFIED_ITEMS=()
  STATE_MISSING_ITEM_IDS=()
  STATE_MISSING_ITEMS=()
  STATE_VERIFICATION_LABELS=()
  STATE_VERIFICATION_KINDS=()
  STATE_VERIFICATION_REPAIR_STRATEGIES=()
  STATE_VERIFICATION_TARGETS=()
  STATE_VERIFICATION_STATUSES=()
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

state_remove_array_item() {
  local array_name="$1"
  local value="$2"
  local filtered_items=()
  local item
  # shellcheck disable=SC2178
  declare -n target_array="$array_name"

  for item in "${target_array[@]}"; do
    [[ "$item" == "$value" ]] && continue
    filtered_items+=("$item")
  done

  target_array=("${filtered_items[@]}")
}

state_record_verification_item() {
  local verification_id="$1"
  local display_label="${2:-$1}"
  local item_kind="${3:-generic}"
  local repair_strategy="${4:-none}"
  local repair_target="${5:-}"
  local item_status="$6"

  [[ -n "$verification_id" ]] || return 1

  STATE_VERIFICATION_LABELS["$verification_id"]="$display_label"
  STATE_VERIFICATION_KINDS["$verification_id"]="$item_kind"
  STATE_VERIFICATION_REPAIR_STRATEGIES["$verification_id"]="$repair_strategy"
  STATE_VERIFICATION_TARGETS["$verification_id"]="$repair_target"
  STATE_VERIFICATION_STATUSES["$verification_id"]="$item_status"

  state_remove_array_item STATE_VERIFIED_ITEM_IDS "$verification_id"
  state_remove_array_item STATE_VERIFIED_ITEMS "$display_label"
  state_remove_array_item STATE_MISSING_ITEM_IDS "$verification_id"
  state_remove_array_item STATE_MISSING_ITEMS "$display_label"

  case "$item_status" in
    verified)
      append_array_item STATE_VERIFIED_ITEM_IDS "$verification_id"
      append_array_item STATE_VERIFIED_ITEMS "$display_label"
      ;;
    missing)
      append_array_item STATE_MISSING_ITEM_IDS "$verification_id"
      append_array_item STATE_MISSING_ITEMS "$display_label"
      ;;
    *)
      return 1
      ;;
  esac
}

state_add_verified_item() {
  state_record_verification_item "$1" "${2:-$1}" "${3:-generic}" "${4:-none}" "${5:-}" "verified"
}

state_add_missing_item() {
  state_record_verification_item "$1" "${2:-$1}" "${3:-generic}" "${4:-none}" "${5:-}" "missing"
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

  component_has_runtime_status "$component_id" || return 0
  STATE_COMPONENT_STATUSES["$component_id"]="$status_value"
}

state_get_component_status() {
  local component_id="$1"

  if ! component_has_runtime_status "$component_id"; then
    printf '%s\n' ""
    return 0
  fi

  printf '%s\n' "${STATE_COMPONENT_STATUSES[$component_id]:-$STATUS_PENDING}"
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
  (( ${#STATE_MISSING_ITEM_IDS[@]} > 0 ))
}

state_has_verified_item() {
  local expected="$1"
  local item

  for item in "${STATE_VERIFIED_ITEM_IDS[@]}"; do
    [[ "$item" == "$expected" ]] && return 0
  done

  return 1
}

state_get_verification_label() {
  printf '%s\n' "${STATE_VERIFICATION_LABELS[$1]:-$1}"
}

state_get_verification_kind() {
  printf '%s\n' "${STATE_VERIFICATION_KINDS[$1]:-generic}"
}

state_get_verification_repair_strategy() {
  printf '%s\n' "${STATE_VERIFICATION_REPAIR_STRATEGIES[$1]:-none}"
}

state_get_verification_target() {
  printf '%s\n' "${STATE_VERIFICATION_TARGETS[$1]:-}"
}
