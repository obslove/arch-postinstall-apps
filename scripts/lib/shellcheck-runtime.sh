#!/usr/bin/env bash
# shellcheck shell=bash
# shellcheck disable=SC2034

REPO_DIR=""
SCRIPT_DIR=""
PACKAGE_FILE=""
EXTRA_PACKAGE_FILE=""
BASHRC_FILE=""
ZSHRC_FILE=""
FISH_CONFIG_FILE=""
REPO_HTTPS_URL=""
REPO_SSH_URL=""
REPOSITORIES_DIR=""
INSTALL_DIR=""
YAY_REPO_DIR=""
YAY_SNAPSHOT_URL=""
SSH_KEY_PATH=""
GITHUB_SSH_KEY_NAME=""
LOG_FILE=""
SUMMARY_FILE=""
CHECK_ONLY=0
EXCLUSIVE_GITHUB_SSH_KEY=0
SKIP_GITHUB_SSH=0
STEP_OUTPUT_ONLY=1
STATE_DIR=""
LOCK_DIR=""
LOCK_HELD=0
SYSTEM_UPDATED=0
STATUS_PENDING=""
STATUS_DONE=""
STATUS_SKIPPED_READY=""
STATUS_SKIPPED_DISABLED=""
STATUS_SKIPPED_DECLINED=""
STATUS_SOFT_FAILED=""
STATUS_HARD_FAILED=""
official_repo_metadata_checked=0
official_repo_metadata_ready=0
github_ssh_status=""
desktop_integration_status=""
aur_helper=""
aur_helper_status=""
temp_clipboard_package=""
step_counter=0
step_open=0
step_total=0
STEP_RESULT_STATUS=""
STEP_RESULT_MESSAGE=""
style_reset=""
style_step=""
style_detail=""
style_success=""
style_warning=""
style_error=""
style_muted=""

official_packages=()
aur_packages=()
official_failed=()
aur_failed=()
support_packages=()
environment_packages=()
verified_commands=()
missing_commands=()
version_info=()
soft_failures=()
cleanup_paths=()

format_github_ssh_status() {
  :
}

format_desktop_integration_status() {
  :
}
