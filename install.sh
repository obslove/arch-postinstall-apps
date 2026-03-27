#!/usr/bin/env bash
# shellcheck shell=bash

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"

exec bash "$REPO_DIR/scripts/install/main.sh" "$@"
