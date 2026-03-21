#!/usr/bin/env bash
# shellcheck shell=bash
# shellcheck source-path=SCRIPTDIR

ops_sudo_auth() {
  run_with_terminal_stdin sudo -v
}

ops_pacman_upgrade_and_install_needed() {
  retry_interactive_log_only sudo pacman -Syu --needed --noconfirm "$@"
}

ops_pacman_upgrade_full() {
  retry_interactive_log_only sudo pacman -Syu --noconfirm
}

ops_pacman_install_needed() {
  retry_interactive_log_only sudo pacman -S --needed --noconfirm "$@"
}

ops_pacman_remove_recursive() {
  retry_interactive_log_only sudo pacman -Rns --noconfirm "$@"
}

ops_pacman_refresh_databases() {
  run_interactive_log_only sudo pacman -Syy --noconfirm
}

ops_backup_pacman_conf() {
  local backup_path="$1"

  sudo cp /etc/pacman.conf "$backup_path"
}

ops_enable_multilib_config() {
  sudo sed -i \
    '/^[[:space:]]*#\[multilib\][[:space:]]*$/,/^[[:space:]]*#Include = \/etc\/pacman.d\/mirrorlist[[:space:]]*$/ s/^[[:space:]]*#//' \
    /etc/pacman.conf
}

ops_download_file() {
  local source_url="$1"
  local destination_path="$2"

  retry curl -fsSL "$source_url" -o "$destination_path"
}

ops_extract_tar_gz() {
  local archive_path="$1"
  local destination_dir="$2"

  tar -xzf "$archive_path" -C "$destination_dir"
}

ops_build_yay_package() {
  local yay_dir="$1"

  retry_log_only build_yay "$yay_dir"
}

ops_git_remote_add_origin() {
  local repo_dir="$1"
  local origin_url="$2"

  git -C "$repo_dir" remote add origin "$origin_url"
}

ops_git_remote_set_origin() {
  local repo_dir="$1"
  local origin_url="$2"

  git -C "$repo_dir" remote set-url origin "$origin_url"
}

ops_git_fetch_origin() {
  local repo_dir="$1"

  retry_log_only git -C "$repo_dir" fetch origin
}

ops_git_checkout_main() {
  local repo_dir="$1"

  run_log_only git -C "$repo_dir" checkout main
}

ops_git_checkout_main_from_origin() {
  local repo_dir="$1"

  run_log_only git -C "$repo_dir" checkout -b main origin/main
}

ops_git_pull_main_ff_only() {
  local repo_dir="$1"

  retry_log_only git -C "$repo_dir" pull --ff-only origin main
}

ops_git_clone_main() {
  local repo_url="$1"
  local repo_dir="$2"

  retry_log_only git clone --branch main --single-branch "$repo_url" "$repo_dir"
}

ops_gh_auth_login() {
  run_gh_auth_flow auth login --web --git-protocol ssh --scopes admin:public_key
}

ops_gh_auth_refresh_admin_public_key() {
  run_gh_auth_flow auth refresh -h github.com -s admin:public_key
}

ops_gh_get_authenticated_login() {
  retry gh api user --jq '.login'
}

ops_gh_list_ssh_keys_tsv() {
  retry gh api user/keys --jq '.[] | [.id, .title, .key] | @tsv'
}

ops_gh_delete_ssh_key() {
  local key_id="$1"

  retry gh api --method DELETE "user/keys/$key_id"
}

ops_gh_create_ssh_key() {
  local key_name="$1"
  local public_key="$2"

  retry gh api user/keys --method POST -f "title=$key_name" -f "key=$public_key" --jq '.id'
}

ops_npm_config_set_prefix() {
  local prefix_path="$1"

  run_log_only npm config set prefix "$prefix_path"
}

ops_npm_install_codex_cli() {
  retry_log_only npm install -g @openai/codex
}

ops_ssh_regenerate_public_key() {
  local private_key_path="$1"
  local public_key_path="$2"

  ssh-keygen -y -f "$private_key_path" >"$public_key_path"
}

ops_ssh_generate_key_pair() {
  local key_comment="$1"
  local key_path="$2"

  ssh-keygen -t ed25519 -C "$key_comment" -f "$key_path" -N ""
}

ops_systemctl_user_daemon_reload() {
  run_log_only systemctl --user daemon-reload
}

ops_systemctl_user_start() {
  run_log_only systemctl --user start "$@"
}

ops_aur_install_needed() {
  local helper_name="$1"
  shift

  retry_log_only "$helper_name" -S --needed --noconfirm "$@"
}
