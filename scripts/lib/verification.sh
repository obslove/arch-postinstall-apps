#!/usr/bin/env bash
# shellcheck shell=bash
# shellcheck source-path=SCRIPTDIR
# shellcheck source=scripts/lib/ops.sh
# shellcheck source=scripts/lib/components.sh
# shellcheck source=scripts/lib/runtime-state.sh

verify_command() {
  local verification_id="$1"
  local display_label="$2"
  local command_name="$3"
  local repair_strategy="${4:-none}"
  local repair_target="${5:-}"

  if command -v "$command_name" >/dev/null 2>&1; then
    state_add_verified_item "$verification_id" "$display_label" "command" "$repair_strategy" "$repair_target"
    return
  fi

  state_add_missing_item "$verification_id" "$display_label" "command" "$repair_strategy" "$repair_target"
}

verify_package() {
  local verification_id="$1"
  local display_label="$2"
  local package_name="$3"
  local repair_strategy="${4:-package_classify}"
  local repair_target="${5:-$package_name}"

  if pacman -Q "$package_name" >/dev/null 2>&1; then
    state_add_verified_item "$verification_id" "$display_label" "package" "$repair_strategy" "$repair_target"
    return
  fi

  state_add_missing_item "$verification_id" "$display_label" "package" "$repair_strategy" "$repair_target"
}

user_service_exists() {
  local service_name="$1"

  systemctl --user cat "$service_name" >/dev/null 2>&1
}

verify_user_service() {
  local verification_id="$1"
  local display_label="$2"
  local service_name="$3"
  local repair_strategy="${4:-service_start}"
  local repair_target="${5:-$service_name}"

  if ! command -v systemctl >/dev/null 2>&1; then
    state_add_missing_item "$verification_id" "$display_label" "service" "$repair_strategy" "$repair_target"
    return
  fi

  if ! user_service_exists "$service_name"; then
    state_add_missing_item "$verification_id" "$display_label" "service" "$repair_strategy" "$repair_target"
    return
  fi

  if systemctl --user --quiet is-active "$service_name"; then
    state_add_verified_item "$verification_id" "$display_label" "service" "$repair_strategy" "$repair_target"
    return
  fi

  state_add_missing_item "$verification_id" "$display_label" "service" "$repair_strategy" "$repair_target"
}

collect_version() {
  local label="$1"
  shift
  local output

  if ! command -v "$1" >/dev/null 2>&1; then
    return
  fi

  output="$("$@" 2>/dev/null | sed -n '1p' || true)"
  if [[ -z "$output" ]]; then
    state_add_version_line "$label: versão indisponível"
    return 0
  fi

  state_add_version_line "$label: $output"
}

verify_installation() {
  local array_name="$1"
  # shellcheck disable=SC2178
  declare -n target_packages="$array_name"
  local verification_component_ids=()
  local package_name

  state_reset_verification_results

  for package_name in "${LOCAL_SUPPORT_PACKAGES[@]}"; do
    verify_package "$package_name" "$package_name" "$package_name" "pacman_package" "$package_name"
  done

  for package_name in "${target_packages[@]}"; do
    case "$package_name" in
      nodejs)
        verify_command "nodejs" "nodejs" "node" "package_classify" "nodejs"
        ;;
      *)
        verify_package "$package_name" "$package_name" "$package_name" "package_classify" "$package_name"
        ;;
    esac
  done

  mapfile -t verification_component_ids < <(component_verification_ids)
  for package_name in "${verification_component_ids[@]}"; do
    if component_is_expected "$package_name"; then
      component_verify "$package_name"
    fi
  done

  collect_version "node" node --version
  collect_version "npm" npm --version
  collect_version "gh" gh --version
  collect_version "codex" codex --version
  collect_version "zen-browser" zen-browser --version
  collect_version "firefox" firefox --version
}
