#!/usr/bin/env bash
# shellcheck shell=bash
# shellcheck disable=SC2034
# shellcheck source-path=SCRIPTDIR
# shellcheck source=scripts/lib/shellcheck-runtime.sh

if false; then
  source "$SCRIPT_DIR/scripts/lib/shellcheck-runtime.sh"
fi

SHARED_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
# shellcheck source=shared.sh
source "$SHARED_LIB_DIR/shared.sh"
# shellcheck source=cli.sh
source "$SHARED_LIB_DIR/cli.sh"
COMPONENT_CONFIG_FILE="$(cd "$SHARED_LIB_DIR/../../config" && pwd)/components.sh"
# shellcheck source=../../config/components.sh
source "$COMPONENT_CONFIG_FILE"

config_init() {
  local repo_dir="$1"

  REPO_DIR="$repo_dir"
  SCRIPT_DIR="$REPO_DIR"
  PACKAGE_FILE="$REPO_DIR/config/packages.txt"
  EXTRA_PACKAGE_FILE="$REPO_DIR/config/packages-extra.txt"
  BASHRC_FILE="$HOME/.bashrc"
  ZSHRC_FILE="$HOME/.zshrc"
  FISH_CONFIG_FILE="$HOME/.config/fish/config.fish"
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
  SYSTEM_UPDATED="${POSTINSTALL_BOOTSTRAP_UPDATED:-${POSTINSTALL_SYSTEM_UPDATED:-0}}"
}

finalize_config() {
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

execution_state_reset() {
  official_packages=()
  aur_packages=()
  official_failed=()
  aur_failed=()
  support_packages=()
  environment_packages=()
  aur_helper=""
  aur_helper_status="não preparado"
  verified_commands=()
  missing_commands=()
  version_info=()
  temp_clipboard_package=""
  official_repo_metadata_checked=0
  official_repo_metadata_ready=0
  github_ssh_status="pendente"
  desktop_integration_status="pendente"
  soft_failures=()
  step_result_reset
}

runtime_state_init() {
  cleanup_paths=()
  step_counter=0
  step_open=0
  step_total=0
  init_output_styles
  execution_state_reset
}

record_soft_failure() {
  local message="$1"

  [[ -n "$message" ]] || return 0
  append_array_item soft_failures "$message"
}

create_directories() {
  announce_step "Criando diretórios..."
  mkdir -p \
    "$HOME/Backups" \
    "$HOME/Codex" \
    "$HOME/Dots" \
    "$HOME/Pictures/Screenshots" \
    "$HOME/Pictures/Wallpapers" \
    "$HOME/Projects" \
    "$REPOSITORIES_DIR" \
    "$HOME/Videos"
}
