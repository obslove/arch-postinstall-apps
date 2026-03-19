#!/usr/bin/env bash
# shellcheck shell=bash
# shellcheck source-path=SCRIPTDIR
# shellcheck source=scripts/lib/shellcheck-runtime.sh
# shellcheck source=scripts/lib/ops.sh
# shellcheck source=scripts/lib/components.sh
# shellcheck source=scripts/lib/runtime-state.sh

if false; then
  source "$SCRIPT_DIR/scripts/lib/shellcheck-runtime.sh"
  source "$SCRIPT_DIR/scripts/lib/ops.sh"
  source "$SCRIPT_DIR/scripts/lib/components.sh"
  source "$SCRIPT_DIR/scripts/lib/runtime-state.sh"
fi

verify_command() {
  local label="$1"
  local command_name="$2"

  if command -v "$command_name" >/dev/null 2>&1; then
    mark_verified_item "$label"
    return
  fi

  mark_missing_item "$label"
}

verify_package() {
  local label="$1"
  local package_name="$2"

  if pacman -Q "$package_name" >/dev/null 2>&1; then
    mark_verified_item "$label"
    return
  fi

  mark_missing_item "$label"
}

user_service_exists() {
  local service_name="$1"

  systemctl --user cat "$service_name" >/dev/null 2>&1
}

verify_user_service() {
  local label="$1"
  local service_name="$2"

  if ! command -v systemctl >/dev/null 2>&1; then
    mark_missing_item "$label"
    return
  fi

  if ! user_service_exists "$service_name"; then
    mark_missing_item "$label"
    return
  fi

  if systemctl --user --quiet is-active "$service_name"; then
    mark_verified_item "$label"
    return
  fi

  mark_missing_item "$label"
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
  local package_name

  state_reset_verification_results

  for package_name in "${target_packages[@]}"; do
    case "$package_name" in
      nodejs)
        verify_command "nodejs" "node"
        ;;
      *)
        verify_package "$package_name" "$package_name"
        ;;
    esac
  done

  component_verify aur_helper
  component_verify desktop_integration
  if component_enabled "codex_cli"; then
    component_verify codex_cli
  fi
  if github_ssh_expected; then
    component_verify github_ssh
  fi

  collect_version "node" node --version
  collect_version "npm" npm --version
  collect_version "gh" gh --version
  collect_version "codex" codex --version
  collect_version "zen-browser" zen-browser --version
  collect_version "google-chrome-stable" google-chrome-stable --version
}
