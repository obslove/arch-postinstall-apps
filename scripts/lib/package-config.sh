#!/usr/bin/env bash
# shellcheck shell=bash
# shellcheck disable=SC2034
# shellcheck source-path=SCRIPTDIR
# shellcheck source=scripts/lib/shellcheck-runtime.sh

if false; then
  source "$SCRIPT_DIR/scripts/lib/shellcheck-runtime.sh"
fi

PACKAGE_CATEGORY_ORDER=()
declare -Ag PACKAGE_CATEGORY_BY_PACKAGE=()

trim_package_config_line() {
  local value="$1"

  value="${value#"${value%%[![:space:]]*}"}"
  value="${value%"${value##*[![:space:]]}"}"
  printf '%s\n' "$value"
}

register_package_category() {
  local category_label="$1"
  local existing_label

  for existing_label in "${PACKAGE_CATEGORY_ORDER[@]}"; do
    [[ "$existing_label" == "$category_label" ]] && return 0
  done

  PACKAGE_CATEGORY_ORDER+=("$category_label")
}

append_package() {
  local array_name="$1"
  local package="$2"
  local existing
  # shellcheck disable=SC2178
  declare -n target_array="$array_name"

  for existing in "${target_array[@]}"; do
    if [[ "$existing" == "$package" ]]; then
      return 1
    fi
  done

  target_array+=("$package")
  return 0
}

package_category_for_package() {
  printf '%s\n' "${PACKAGE_CATEGORY_BY_PACKAGE[$1]:-Geral}"
}

load_package_file() {
  local package_path="$1"
  local array_name="$2"
  local default_category_label="$3"
  local current_category_label="$default_category_label"
  local line
  local category_label=""

  if [[ ! -f "$package_path" ]]; then
    if [[ "$package_path" == "$EXTRA_PACKAGE_FILE" ]]; then
      announce_detail "Pacotes extras não encontrados em $package_path. Etapa ignorada."
    fi
    return 0
  fi

  register_package_category "$default_category_label"

  while IFS= read -r line || [[ -n "$line" ]]; do
    line="$(trim_package_config_line "$line")"
    [[ -n "$line" ]] || continue
    [[ "$line" =~ ^[[:space:]]*# ]] && continue

    if [[ "$line" =~ ^\[(.+)\]$ ]]; then
      category_label="$(trim_package_config_line "${BASH_REMATCH[1]}")"
      [[ -n "$category_label" ]] || {
        announce_error "Categoria inválida em $package_path."
        return 1
      }
      current_category_label="$category_label"
      register_package_category "$current_category_label"
      continue
    fi

    if append_package "$array_name" "$line"; then
      PACKAGE_CATEGORY_BY_PACKAGE["$line"]="$current_category_label"
    fi
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
  PACKAGE_CATEGORY_ORDER=()
  PACKAGE_CATEGORY_BY_PACKAGE=()
  load_package_file "$PACKAGE_FILE" "$array_name" "Geral"
  load_package_file "$EXTRA_PACKAGE_FILE" "$array_name" "Extras"
}

classify_package_origin() {
  local package_name="$1"
  local origin_status=0

  package_exists_in_official_repos "$package_name"
  origin_status=$?

  if [[ "$origin_status" == "0" ]]; then
    printf 'official\n'
    return 0
  fi

  if [[ "$origin_status" == "1" ]]; then
    printf 'aur\n'
    return 0
  fi

  announce_error "Não foi possível classificar o pacote '$package_name' entre repositório oficial e AUR."
  return 1
}

target_packages_have_origin() {
  local array_name="$1"
  local expected_origin="$2"
  # shellcheck disable=SC2178
  declare -n target_packages="$array_name"
  local package_name
  local package_origin=""

  for package_name in "${target_packages[@]}"; do
    package_origin="$(classify_package_origin "$package_name")" || return 2
    [[ "$package_origin" == "$expected_origin" ]] && return 0
  done

  return 1
}

target_packages_have_official_entries() {
  target_packages_have_origin "$1" "official"
}

target_packages_have_aur_entries() {
  target_packages_have_origin "$1" "aur"
}

collect_packages_by_origin() {
  local source_array_name="$1"
  local expected_origin="$2"
  local target_array_name="$3"
  # shellcheck disable=SC2178
  declare -n source_packages="$source_array_name"
  # shellcheck disable=SC2178
  declare -n target_packages="$target_array_name"
  local package_name
  local package_origin=""

  target_packages=()

  for package_name in "${source_packages[@]}"; do
    package_origin="$(classify_package_origin "$package_name")" || return 1
    [[ "$package_origin" == "$expected_origin" ]] || continue
    target_packages+=("$package_name")
  done
}

report_requested_main_packages() {
  local array_name="$1"
  # shellcheck disable=SC2178
  declare -n target_packages="$array_name"
  local package_name
  local package_origin=""

  for package_name in "${target_packages[@]}"; do
    package_origin="$(classify_package_origin "$package_name")" || return 1
    case "$package_origin" in
      official)
        report_add_requested_main_official_package "$package_name"
        ;;
      aur)
        report_add_requested_main_aur_package "$package_name"
        ;;
    esac
  done
}
