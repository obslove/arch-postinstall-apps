#!/usr/bin/env bash
# shellcheck shell=bash
# shellcheck disable=SC2034

readonly -a ENABLED_SPECIAL_COMPONENTS=(
  codex_cli
)

readonly -a SCRIPT_SUPPORT_PACKAGES=(
  git
  base-devel
  yay
  github-cli
  openssh
)

readonly -a AUR_HELPER_SUPPORT_PACKAGES=(
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

component_enabled() {
  config_array_contains ENABLED_SPECIAL_COMPONENTS "$1"
}
