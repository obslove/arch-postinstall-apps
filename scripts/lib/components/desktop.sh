#!/usr/bin/env bash
# shellcheck shell=bash
# shellcheck disable=SC2034
# shellcheck source-path=SCRIPTDIR
# shellcheck source=scripts/lib/shellcheck-runtime.sh
# shellcheck source=scripts/lib/ops.sh
# shellcheck source=scripts/lib/status.sh
# shellcheck source=scripts/lib/components.sh
# shellcheck source=scripts/lib/runtime-state.sh

if false; then
  source "$SCRIPT_DIR/scripts/lib/shellcheck-runtime.sh"
  source "$SCRIPT_DIR/scripts/lib/ops.sh"
  source "$SCRIPT_DIR/scripts/lib/status.sh"
  source "$SCRIPT_DIR/scripts/lib/components.sh"
  source "$SCRIPT_DIR/scripts/lib/runtime-state.sh"
fi

desktop_integration_ready() {
  local package_name

  for package_name in "${DESKTOP_INTEGRATION_PACKAGES[@]}"; do
    if ! pacman -Q "$package_name" >/dev/null 2>&1; then
      return 1
    fi
  done

  return 0
}

component_detect_desktop_integration() {
  desktop_integration_ready
}

component_apply_desktop_integration() {
  local package_name
  local missing_packages=()

  report_reset_environment_packages
  for package_name in "${DESKTOP_INTEGRATION_PACKAGES[@]}"; do
    report_add_requested_environment_package "$package_name"
  done

  if desktop_integration_ready; then
    report_set_component_outcome "desktop_integration" "$COMPONENT_OUTCOME_REUSED"
    for package_name in "${DESKTOP_INTEGRATION_PACKAGES[@]}"; do
      report_add_reused_environment_package "$package_name"
    done
    announce_detail "A integração desktop já está preparada. Etapa ignorada."
    return 0
  fi

  collect_missing_packages missing_packages "${DESKTOP_INTEGRATION_PACKAGES[@]}"
  announce_detail "Garantindo integração desktop..."
  if ! ops_pacman_install_needed "${missing_packages[@]}"; then
    report_set_component_outcome "desktop_integration" "$COMPONENT_OUTCOME_FAILED"
    announce_error "Não foi possível instalar a integração desktop."
    return 1
  fi

  for package_name in "${DESKTOP_INTEGRATION_PACKAGES[@]}"; do
    if ! config_array_contains missing_packages "$package_name"; then
      report_add_reused_environment_package "$package_name"
    fi
  done
  for package_name in "${missing_packages[@]}"; do
    report_add_changed_environment_package "$package_name"
  done
  if ! mark_checkpoint "desktop_integration"; then
    report_set_component_outcome "desktop_integration" "$COMPONENT_OUTCOME_FAILED"
    announce_error "Não foi possível registrar o checkpoint da integração desktop."
    return 1
  fi

  report_set_component_outcome "desktop_integration" "$COMPONENT_OUTCOME_CHANGED"
}

start_desktop_user_services() {
  if ! command -v systemctl >/dev/null 2>&1; then
    return 1
  fi

  ops_systemctl_user_daemon_reload || true
  ops_systemctl_user_start "${DESKTOP_USER_SERVICES[@]}"
}

component_verify_desktop_integration() {
  local package_name
  local service_name

  for package_name in "${DESKTOP_INTEGRATION_PACKAGES[@]}"; do
    case "$package_name" in
      xdg-utils)
        if command -v xdg-open >/dev/null 2>&1; then
          state_add_verified_item "xdg-utils" "xdg-utils" "command" "pacman_package" "xdg-utils"
        elif command -v gio >/dev/null 2>&1; then
          state_add_verified_item "xdg-utils" "xdg-utils" "command" "pacman_package" "xdg-utils"
        else
          state_add_missing_item "xdg-utils" "xdg-utils" "command" "pacman_package" "xdg-utils"
        fi
        ;;
      pipewire|wireplumber)
        verify_command "$package_name" "$package_name" "$package_name" "pacman_package" "$package_name"
        ;;
      *)
        verify_package "$package_name" "$package_name" "$package_name" "pacman_package" "$package_name"
        ;;
    esac
  done

  if command -v wl-copy >/dev/null 2>&1 && command -v wl-paste >/dev/null 2>&1; then
    state_add_verified_item "clipboard" "clipboard" "command" "none" ""
  elif package_is_installed "${TEMPORARY_CLIPBOARD_PACKAGES[0]}"; then
    state_add_missing_item "${TEMPORARY_CLIPBOARD_PACKAGES[0]}" "${TEMPORARY_CLIPBOARD_PACKAGES[0]}" "package" "pacman_package" "${TEMPORARY_CLIPBOARD_PACKAGES[0]}"
  fi

  for service_name in "${DESKTOP_USER_SERVICES[@]}"; do
    verify_user_service "$service_name" "$service_name" "$service_name" "service_start" "$service_name"
  done

  if state_has_verified_item "${DESKTOP_USER_SERVICES[0]}" && \
    state_has_verified_item "${DESKTOP_USER_SERVICES[1]}" && \
    state_has_verified_item "${DESKTOP_USER_SERVICES[2]}"; then
    state_add_verified_item "screen-sharing-stack" "screen-sharing-stack" "composite" "service_start" "desktop_user_services"
  else
    state_add_missing_item "screen-sharing-stack" "screen-sharing-stack" "composite" "service_start" "desktop_user_services"
  fi
}
