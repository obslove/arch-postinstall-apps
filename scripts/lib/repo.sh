#!/usr/bin/env bash
# shellcheck shell=bash
# shellcheck source-path=SCRIPTDIR
# shellcheck source=scripts/lib/shellcheck-runtime.sh

if false; then
  source "$SCRIPT_DIR/scripts/lib/shellcheck-runtime.sh"
fi

build_ssh_key_name() {
  local github_login=""

  if [[ -n "$GITHUB_SSH_KEY_NAME" ]]; then
    printf '%s\n' "$GITHUB_SSH_KEY_NAME"
    return
  fi

  if command -v gh >/dev/null 2>&1; then
    github_login="$(gh api user --jq '.login' 2>/dev/null || true)"
    if [[ -n "$github_login" ]]; then
      printf '%s\n' "$github_login"
      return
    fi
  fi

  printf '%s\n' "$USER"
}

current_public_ssh_key() {
  [[ -f "${SSH_KEY_PATH}.pub" ]] || return 1
  awk 'NR == 1 { print $1, $2 }' "${SSH_KEY_PATH}.pub"
}

find_current_github_ssh_key() {
  local current_key

  current_key="$(current_public_ssh_key)" || return 1
  gh api user/keys --jq ".[] | select(.key == \"$current_key\") | [.id, .title] | @tsv"
}

github_has_expected_ssh_key_name() {
  local key_data
  local current_key_name=""

  key_data="$(find_current_github_ssh_key 2>/dev/null || true)"
  [[ -n "$key_data" ]] || return 1
  IFS=$'\t' read -r _ current_key_name <<<"$key_data"
  [[ "$current_key_name" == "$(build_ssh_key_name)" ]]
}

github_ssh_ready() {
  [[ -f "${SSH_KEY_PATH}.pub" ]] || return 1
  command -v gh >/dev/null 2>&1 || return 1
  gh auth status >/dev/null 2>&1 || return 1
  has_checkpoint "github_ssh" || return 1
  github_has_expected_ssh_key_name
}

desired_repo_origin_url() {
  if github_ssh_ready; then
    printf '%s\n' "$REPO_SSH_URL"
    return
  fi

  printf '%s\n' "$REPO_HTTPS_URL"
}

ensure_repo_origin_remote() {
  local repo_dir="$1"
  local current_origin_url=""
  local desired_origin_url

  desired_origin_url="$(desired_repo_origin_url)"
  current_origin_url="$(git -C "$repo_dir" remote get-url origin 2>/dev/null || true)"

  if [[ -z "$current_origin_url" ]]; then
    git -C "$repo_dir" remote add origin "$desired_origin_url"
    return
  fi

  if [[ "$current_origin_url" != "$REPO_HTTPS_URL" && "$current_origin_url" != "$REPO_SSH_URL" ]]; then
    announce_detail "Foi detectado um remoto origin personalizado em $repo_dir. A configuração atual será mantida."
    return
  fi

  if [[ "$current_origin_url" != "$desired_origin_url" ]]; then
    git -C "$repo_dir" remote set-url origin "$desired_origin_url"
  fi
}

get_repo_branch() {
  local repo_dir="$1"
  local branch_name=""

  if ! git -C "$repo_dir" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    return 1
  fi

  branch_name="$(git -C "$repo_dir" symbolic-ref --quiet --short HEAD 2>/dev/null || true)"
  if [[ -n "$branch_name" ]]; then
    printf '%s\n' "$branch_name"
    return 0
  fi

  branch_name="$(git -C "$repo_dir" rev-parse --short HEAD 2>/dev/null || true)"
  [[ -n "$branch_name" ]] || return 1
  printf 'detached@%s\n' "$branch_name"
}

current_repo_origin_status() {
  local repo_dir="$1"
  local current_origin_url=""

  current_origin_url="$(git -C "$repo_dir" remote get-url origin 2>/dev/null || true)"
  case "$current_origin_url" in
    "$REPO_SSH_URL")
      printf '%s\n' "ssh"
      ;;
    "$REPO_HTTPS_URL")
      printf '%s\n' "https"
      ;;
    "")
      printf '%s\n' "ausente"
      ;;
    *)
      printf '%s\n' "personalizado"
      ;;
  esac
}

current_repo_commit_short() {
  local repo_dir="$1"
  local commit_hash=""

  commit_hash="$(git -C "$repo_dir" rev-parse --short HEAD 2>/dev/null || true)"
  [[ -n "$commit_hash" ]] || {
    printf '%s\n' "indisponível"
    return 0
  }

  printf '%s\n' "$commit_hash"
}
