#!/usr/bin/env bash
# shellcheck shell=bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
LOCAL_FILE="$REPO_DIR/install.sh"
RAW_URL="https://raw.githubusercontent.com/obslove/arch-postinstall-apps/main/install.sh"
PUBLISHED_URL="https://obslove.dev"
RETRY_COUNT=1
SLEEP_SECONDS=10
CHECK_LOCAL_MATCH=0

usage() {
  cat <<'EOF'
Uso:
  bash scripts/check-published-bootstrap.sh
  bash scripts/check-published-bootstrap.sh --check-local-match
  bash scripts/check-published-bootstrap.sh --retry 18 --sleep 10
EOF
}

download_to() {
  local url="$1"
  local destination="$2"

  curl -fsSL "$url" -o "$destination"
}

compare_files() {
  local left_label="$1"
  local left_path="$2"
  local right_label="$3"
  local right_path="$4"

  if cmp -s "$left_path" "$right_path"; then
    return 0
  fi

  printf 'Erro: %s difere de %s.\n' "$left_label" "$right_label" >&2
  diff -u "$left_path" "$right_path" >&2 || true
  return 1
}

check_once() {
  local raw_file
  local published_file
  local status=0

  raw_file="$(mktemp)"
  published_file="$(mktemp)"

  download_to "$RAW_URL" "$raw_file"
  download_to "$PUBLISHED_URL" "$published_file"

  if (( CHECK_LOCAL_MATCH == 1 )); then
    compare_files "install.sh local" "$LOCAL_FILE" "raw main" "$raw_file" || status=1
  fi

  compare_files "bootstrap publicado" "$published_file" "raw main" "$raw_file" || status=1

  rm -f "$raw_file" "$published_file"
  return "$status"
}

main() {
  local attempt=1

  while (($# > 0)); do
    case "$1" in
      --retry)
        RETRY_COUNT="$2"
        shift 2
        ;;
      --sleep)
        SLEEP_SECONDS="$2"
        shift 2
        ;;
      --check-local-match)
        CHECK_LOCAL_MATCH=1
        shift
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      *)
        printf 'Erro: opção desconhecida: %s\n' "$1" >&2
        usage >&2
        exit 1
        ;;
    esac
  done

  while (( attempt <= RETRY_COUNT )); do
    if check_once; then
      return 0
    fi

    if (( attempt == RETRY_COUNT )); then
      return 1
    fi

    sleep "$SLEEP_SECONDS"
    attempt=$((attempt + 1))
  done
}

main "$@"
