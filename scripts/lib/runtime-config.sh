#!/usr/bin/env bash
# shellcheck shell=bash
# shellcheck disable=SC2034

config_init_common_defaults() {
  REPO_HTTPS_URL="https://github.com/obslove/arch-postinstall-apps.git"
  REPO_SSH_URL="git@github.com:obslove/arch-postinstall-apps.git"
  REPOSITORIES_DIR="${REPOSITORIES_DIR:-$HOME/Repositories}"
  INSTALL_DIR="${BOOTSTRAP_DIR:-$REPOSITORIES_DIR/arch-postinstall-apps}"
  YAY_REPO_DIR="${YAY_REPO_DIR:-$REPOSITORIES_DIR/yay}"
  YAY_SNAPSHOT_URL="${YAY_SNAPSHOT_URL:-https://aur.archlinux.org/cgit/aur.git/snapshot/yay.tar.gz}"
  SSH_KEY_PATH="${SSH_KEY_PATH:-$HOME/.ssh/id_ed25519}"
  GITHUB_SSH_KEY_NAME=""
  LOG_FILE="${POSTINSTALL_LOG_FILE:-$HOME/Backups/arch-postinstall.log}"
  SUMMARY_FILE="${POSTINSTALL_SUMMARY_FILE:-$HOME/Backups/arch-postinstall-summary.txt}"
  CHECK_ONLY=0
  EXCLUSIVE_GITHUB_SSH_KEY=0
  SKIP_GITHUB_SSH=0
  STEP_OUTPUT_ONLY=1
  STATE_DIR="${POSTINSTALL_STATE_DIR:-${XDG_STATE_HOME:-$HOME/.local/state}/arch-postinstall-apps}"
  LOCK_DIR="${POSTINSTALL_LOCK_DIR:-$STATE_DIR/lock}"
  LOCK_HELD="${POSTINSTALL_LOCK_HELD:-0}"
}

config_init_user_shell_paths() {
  BASHRC_FILE="$HOME/.bashrc"
  ZSHRC_FILE="$HOME/.zshrc"
  FISH_CONFIG_FILE="$HOME/.config/fish/config.fish"
}

config_init_repo_paths() {
  local repo_dir="$1"

  REPO_DIR="$repo_dir"
  SCRIPT_DIR="$REPO_DIR"
  PACKAGE_FILE="$REPO_DIR/config/packages.txt"
  EXTRA_PACKAGE_FILE="$REPO_DIR/config/packages-extra.txt"
}

config_init_runtime() {
  local repo_dir="$1"

  config_init_common_defaults
  config_init_user_shell_paths
  config_init_repo_paths "$repo_dir"
  SYSTEM_UPDATED="${POSTINSTALL_BOOTSTRAP_UPDATED:-${POSTINSTALL_SYSTEM_UPDATED:-0}}"
}

config_init_bootstrap() {
  config_init_common_defaults
  config_init_user_shell_paths
  config_init_repo_paths "$INSTALL_DIR"
  SYSTEM_UPDATED=0
}

config_finalize() {
  readonly REPO_DIR
  readonly SCRIPT_DIR
  readonly PACKAGE_FILE
  readonly EXTRA_PACKAGE_FILE
  readonly BASHRC_FILE
  readonly ZSHRC_FILE
  readonly FISH_CONFIG_FILE
  readonly REPO_HTTPS_URL
  readonly REPO_SSH_URL
  readonly REPOSITORIES_DIR
  readonly INSTALL_DIR
  readonly YAY_REPO_DIR
  readonly YAY_SNAPSHOT_URL
  readonly SSH_KEY_PATH
  readonly GITHUB_SSH_KEY_NAME
  readonly LOG_FILE
  readonly SUMMARY_FILE
  readonly CHECK_ONLY
  readonly EXCLUSIVE_GITHUB_SSH_KEY
  readonly SKIP_GITHUB_SSH
  readonly STEP_OUTPUT_ONLY
  readonly STATE_DIR
  readonly LOCK_DIR
  readonly SYSTEM_UPDATED
}
