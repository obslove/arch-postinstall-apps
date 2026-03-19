#!/usr/bin/env bash
# shellcheck shell=bash
# shellcheck disable=SC2034
# shellcheck source-path=SCRIPTDIR
# shellcheck source=scripts/lib/shellcheck-runtime.sh

if false; then
  source "$SCRIPT_DIR/scripts/lib/shellcheck-runtime.sh"
fi

append_package() {
  local array_name="$1"
  local package="$2"
  local existing
  # shellcheck disable=SC2178
  declare -n target_array="$array_name"

  for existing in "${target_array[@]}"; do
    if [[ "$existing" == "$package" ]]; then
      return
    fi
  done

  target_array+=("$package")
}

load_package_file() {
  local package_path="$1"
  local array_name="$2"
  local line

  if [[ ! -f "$package_path" ]]; then
    if [[ "$package_path" == "$EXTRA_PACKAGE_FILE" ]]; then
      announce_detail "Pacotes extras não encontrados em $package_path. Etapa ignorada."
    fi
    return 0
  fi

  while IFS= read -r line || [[ -n "$line" ]]; do
    line="${line#"${line%%[![:space:]]*}"}"
    line="${line%"${line##*[![:space:]]}"}"
    [[ -n "$line" ]] || continue
    [[ "$line" =~ ^[[:space:]]*# ]] && continue
    append_package "$array_name" "$line"
  done <"$package_path"
}

load_packages() {
  local array_name="$1"
  # shellcheck disable=SC2178
  declare -n target_array="$array_name"

  [[ -f "$PACKAGE_FILE" ]] || {
    announce_error "Lista de pacotes não encontrada em $PACKAGE_FILE"
    return 1
  }

  target_array=()
  load_package_file "$PACKAGE_FILE" "$array_name"
  load_package_file "$EXTRA_PACKAGE_FILE" "$array_name"
}

calculate_install_step_total() {
  local array_name="$1"
  # shellcheck disable=SC2178
  declare -n target_packages="$array_name"
  local package
  local total=8
  local has_official=0
  local has_aur=0

  for package in "${target_packages[@]}"; do
    if pacman -Si -- "$package" >/dev/null 2>&1; then
      has_official=1
    else
      has_aur=1
    fi
  done

  if component_enabled "codex_cli"; then
    total=$((total + 1))
  fi
  (( has_official == 1 )) && total=$((total + 1))
  (( has_aur == 1 )) && total=$((total + 1))

  printf '%s\n' "$total"
}
