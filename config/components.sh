#!/usr/bin/env bash
# shellcheck shell=bash
# shellcheck disable=SC2034

readonly -a ENABLED_SPECIAL_COMPONENTS=(
  codex_cli
)

readonly -a COMPONENT_REGISTRY_IDS=(
  aur_helper
  codex_cli
  desktop_integration
  github_ssh
)

readonly -a COMPONENT_PRE_PACKAGE_PIPELINE_IDS=(
  aur_helper
)

readonly -a COMPONENT_POST_PACKAGE_PIPELINE_IDS=(
  desktop_integration
  github_ssh
)

readonly -a COMPONENT_CHECK_ONLY_DETECTION_IDS=(
  aur_helper
  desktop_integration
  github_ssh
)

readonly -a COMPONENT_VERIFICATION_IDS=(
  aur_helper
  codex_cli
  desktop_integration
  github_ssh
)

readonly -a COMPONENT_SUMMARY_STATUS_IDS=(
  github_ssh
  desktop_integration
  aur_helper
)

readonly -a COMPONENT_CHECKPOINT_SUMMARY_IDS=(
  codex_cli
  desktop_integration
  github_ssh
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

component_registry_ids() {
  print_config_array COMPONENT_REGISTRY_IDS
}

component_pre_package_pipeline_ids() {
  print_config_array COMPONENT_PRE_PACKAGE_PIPELINE_IDS
}

component_post_package_pipeline_ids() {
  print_config_array COMPONENT_POST_PACKAGE_PIPELINE_IDS
}

component_check_only_detection_ids() {
  print_config_array COMPONENT_CHECK_ONLY_DETECTION_IDS
}

component_verification_ids() {
  print_config_array COMPONENT_VERIFICATION_IDS
}

component_summary_status_ids() {
  print_config_array COMPONENT_SUMMARY_STATUS_IDS
}

component_checkpoint_summary_ids() {
  print_config_array COMPONENT_CHECKPOINT_SUMMARY_IDS
}

component_summary_label() {
  case "$1" in
    aur_helper)
      printf '%s\n' "Helper AUR"
      ;;
    codex_cli)
      printf '%s\n' "Codex CLI"
      ;;
    desktop_integration)
      printf '%s\n' "Integração desktop"
      ;;
    github_ssh)
      printf '%s\n' "GitHub SSH"
      ;;
    *)
      printf '%s\n' "$1"
      ;;
  esac
}

component_is_expected() {
  case "$1" in
    aur_helper|desktop_integration)
      return 0
      ;;
    codex_cli)
      component_enabled "codex_cli"
      ;;
    github_ssh)
      github_ssh_expected
      ;;
    *)
      return 1
      ;;
  esac
}

component_has_runtime_status() {
  case "$1" in
    desktop_integration|github_ssh)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

component_pipeline_step_function() {
  case "$1" in
    aur_helper)
      printf '%s\n' "pipeline_prepare_aur_helper_step"
      ;;
    desktop_integration)
      printf '%s\n' "pipeline_desktop_integration_step"
      ;;
    github_ssh)
      printf '%s\n' "pipeline_github_ssh_step"
      ;;
    *)
      return 1
      ;;
  esac
}
