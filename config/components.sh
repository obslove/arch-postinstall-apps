#!/usr/bin/env bash
# shellcheck shell=bash
# shellcheck disable=SC2034

readonly -a ENABLED_SPECIAL_COMPONENTS=(
  codex_cli
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
