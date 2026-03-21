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
}

report_mark_change() {
  append_array_item REPORT_CHANGE_MARKERS "$1"
}

report_has_changes() {
  local component_id
  local component_outcome

  if (( ${#REPORT_CHANGE_MARKERS[@]} > 0 )); then
    return 0
  fi

  if (( ${#REPORT_CHANGED_MAIN_OFFICIAL_PACKAGES[@]} > 0 || \
    ${#REPORT_CHANGED_MAIN_AUR_PACKAGES[@]} > 0 || \
    ${#REPORT_CHANGED_SUPPORT_PACKAGES[@]} > 0 || \
    ${#REPORT_CHANGED_ENVIRONMENT_PACKAGES[@]} > 0 )); then
    return 0
  fi

  for component_id in "${!REPORT_COMPONENT_OUTCOMES[@]}"; do
    component_outcome="${REPORT_COMPONENT_OUTCOMES[$component_id]:-}"
    [[ "$(component_outcome_changed_flag "$component_outcome")" == "1" ]] && return 0
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

  REPORT_COMPONENT_OUTCOMES["$component_id"]="$outcome"

  if [[ "$(component_outcome_changed_flag "$outcome")" == "1" ]]; then
    report_mark_change "component:$component_id"
  fi
}

report_get_component_outcome() {
  printf '%s\n' "${REPORT_COMPONENT_OUTCOMES[$1]:-$COMPONENT_OUTCOME_PENDING}"
}
