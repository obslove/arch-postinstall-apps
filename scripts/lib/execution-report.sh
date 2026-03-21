#!/usr/bin/env bash
# shellcheck shell=bash
# shellcheck disable=SC2034

REPORT_REQUESTED_MAIN_OFFICIAL_PACKAGES=()
REPORT_REQUESTED_MAIN_AUR_PACKAGES=()
REPORT_REUSED_MAIN_OFFICIAL_PACKAGES=()
REPORT_REUSED_MAIN_AUR_PACKAGES=()
REPORT_CHANGED_MAIN_OFFICIAL_PACKAGES=()
REPORT_CHANGED_MAIN_AUR_PACKAGES=()
REPORT_REQUESTED_SUPPORT_PACKAGES=()
REPORT_REUSED_SUPPORT_PACKAGES=()
REPORT_CHANGED_SUPPORT_PACKAGES=()
REPORT_REQUESTED_ENVIRONMENT_PACKAGES=()
REPORT_REUSED_ENVIRONMENT_PACKAGES=()
REPORT_CHANGED_ENVIRONMENT_PACKAGES=()
REPORT_CHANGE_MARKERS=()
declare -Ag REPORT_COMPONENT_OUTCOMES=()
declare -Ag REPORT_COMPONENT_CHANGED_FLAGS=()

execution_report_reset() {
  REPORT_REQUESTED_MAIN_OFFICIAL_PACKAGES=()
  REPORT_REQUESTED_MAIN_AUR_PACKAGES=()
  REPORT_REUSED_MAIN_OFFICIAL_PACKAGES=()
  REPORT_REUSED_MAIN_AUR_PACKAGES=()
  REPORT_CHANGED_MAIN_OFFICIAL_PACKAGES=()
  REPORT_CHANGED_MAIN_AUR_PACKAGES=()
  REPORT_REQUESTED_SUPPORT_PACKAGES=()
  REPORT_REUSED_SUPPORT_PACKAGES=()
  REPORT_CHANGED_SUPPORT_PACKAGES=()
  REPORT_REQUESTED_ENVIRONMENT_PACKAGES=()
  REPORT_REUSED_ENVIRONMENT_PACKAGES=()
  REPORT_CHANGED_ENVIRONMENT_PACKAGES=()
  REPORT_CHANGE_MARKERS=()
  REPORT_COMPONENT_OUTCOMES=()
  REPORT_COMPONENT_CHANGED_FLAGS=()
}

report_mark_change() {
  append_array_item REPORT_CHANGE_MARKERS "$1"
}

report_has_changes() {
  local component_id

  if (( ${#REPORT_CHANGE_MARKERS[@]} > 0 )); then
    return 0
  fi

  if (( ${#REPORT_CHANGED_MAIN_OFFICIAL_PACKAGES[@]} > 0 || \
    ${#REPORT_CHANGED_MAIN_AUR_PACKAGES[@]} > 0 || \
    ${#REPORT_CHANGED_SUPPORT_PACKAGES[@]} > 0 || \
    ${#REPORT_CHANGED_ENVIRONMENT_PACKAGES[@]} > 0 )); then
    return 0
  fi

  for component_id in "${!REPORT_COMPONENT_CHANGED_FLAGS[@]}"; do
    [[ "${REPORT_COMPONENT_CHANGED_FLAGS[$component_id]:-0}" == "1" ]] && return 0
  done

  return 1
}

report_add_requested_main_official_package() {
  append_array_item REPORT_REQUESTED_MAIN_OFFICIAL_PACKAGES "$1"
}

report_add_reused_main_official_package() {
  append_array_item REPORT_REUSED_MAIN_OFFICIAL_PACKAGES "$1"
}

report_add_changed_main_official_package() {
  append_array_item REPORT_CHANGED_MAIN_OFFICIAL_PACKAGES "$1"
  report_mark_change "main_official:$1"
}

report_add_requested_main_aur_package() {
  append_array_item REPORT_REQUESTED_MAIN_AUR_PACKAGES "$1"
}

report_add_reused_main_aur_package() {
  append_array_item REPORT_REUSED_MAIN_AUR_PACKAGES "$1"
}

report_add_changed_main_aur_package() {
  append_array_item REPORT_CHANGED_MAIN_AUR_PACKAGES "$1"
  report_mark_change "main_aur:$1"
}

report_add_requested_support_package() {
  append_array_item REPORT_REQUESTED_SUPPORT_PACKAGES "$1"
}

report_add_reused_support_package() {
  append_array_item REPORT_REUSED_SUPPORT_PACKAGES "$1"
}

report_add_changed_support_package() {
  append_array_item REPORT_CHANGED_SUPPORT_PACKAGES "$1"
  report_mark_change "support:$1"
}

report_add_requested_environment_package() {
  append_array_item REPORT_REQUESTED_ENVIRONMENT_PACKAGES "$1"
}

report_add_reused_environment_package() {
  append_array_item REPORT_REUSED_ENVIRONMENT_PACKAGES "$1"
}

report_add_changed_environment_package() {
  append_array_item REPORT_CHANGED_ENVIRONMENT_PACKAGES "$1"
  report_mark_change "environment:$1"
}

report_reset_environment_packages() {
  REPORT_REQUESTED_ENVIRONMENT_PACKAGES=()
  REPORT_REUSED_ENVIRONMENT_PACKAGES=()
  REPORT_CHANGED_ENVIRONMENT_PACKAGES=()
}

report_set_component_outcome() {
  local component_id="$1"
  local outcome="$2"
  local changed_flag="${3:-0}"

  REPORT_COMPONENT_OUTCOMES["$component_id"]="$outcome"
  REPORT_COMPONENT_CHANGED_FLAGS["$component_id"]="$changed_flag"

  if [[ "$changed_flag" == "1" ]]; then
    report_mark_change "component:$component_id"
  fi
}

report_get_component_outcome() {
  printf '%s\n' "${REPORT_COMPONENT_OUTCOMES[$1]:-}"
}
