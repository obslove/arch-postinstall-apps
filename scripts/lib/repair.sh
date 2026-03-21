#!/usr/bin/env bash
# shellcheck shell=bash
# shellcheck source-path=SCRIPTDIR
# shellcheck source=scripts/lib/shellcheck-runtime.sh
# shellcheck source=scripts/lib/ops.sh
# shellcheck source=scripts/lib/runtime-state.sh
# shellcheck source=scripts/lib/repo.sh
# shellcheck source=scripts/lib/package-repos.sh
# shellcheck source=scripts/lib/components/aur-helper.sh
# shellcheck source=scripts/lib/components/codex.sh
# shellcheck source=scripts/lib/components/desktop.sh

if false; then
  source "$SCRIPT_DIR/scripts/lib/shellcheck-runtime.sh"
  source "$SCRIPT_DIR/scripts/lib/ops.sh"
  source "$SCRIPT_DIR/scripts/lib/runtime-state.sh"
  source "$SCRIPT_DIR/scripts/lib/repo.sh"
  source "$SCRIPT_DIR/scripts/lib/package-repos.sh"
  source "$SCRIPT_DIR/scripts/lib/components/aur-helper.sh"
  source "$SCRIPT_DIR/scripts/lib/components/codex.sh"
  source "$SCRIPT_DIR/scripts/lib/components/desktop.sh"
fi

attempt_final_repair_once() {
  local array_name="$1"
  local verification_id
  local verification_label=""
  local repair_strategy=""
  local repair_target=""
  local repair_pacman_packages=()
  local repair_aur_packages=()
  local pacman_missing_packages=()
  local aur_package
  local aur_helper_name=""
  local package_origin_status
  local should_repair_codex=0
  local should_repair_origin=0
  local should_start_services=0

  if ! state_has_missing_items; then
    return 0
  fi

  announce_step "Tentando corrigir itens ausentes..."
  for verification_id in "${STATE_MISSING_ITEM_IDS[@]}"; do
    verification_label="$(state_get_verification_label "$verification_id")"
    repair_strategy="$(state_get_verification_repair_strategy "$verification_id")"
    repair_target="$(state_get_verification_target "$verification_id")"

    case "$repair_strategy" in
      none|"")
        continue
        ;;
      pacman_package)
        [[ -n "$repair_target" ]] || {
          announce_error "Item ausente sem alvo de reparo via pacman: $verification_label"
          return 1
        }
        append_array_item repair_pacman_packages "$repair_target"
        ;;
      package_classify)
        [[ -n "$repair_target" ]] || {
          announce_error "Item ausente sem alvo classificável para reparo: $verification_label"
          return 1
        }
        if package_exists_in_official_repos "$repair_target"; then
          package_origin_status=0
        else
          package_origin_status=$?
        fi

        if [[ "$package_origin_status" == "0" ]]; then
          append_array_item repair_pacman_packages "$repair_target"
          continue
        fi

        if [[ "$package_origin_status" == "2" ]]; then
          announce_error "Não foi possível classificar o item ausente '$verification_label' para a correção automática."
          return 1
        fi

        append_array_item repair_aur_packages "$repair_target"
        ;;
      service_start)
        should_start_services=1
        ;;
      codex_cli_setup)
        should_repair_codex=1
        ;;
      repo_origin_ssh)
        should_repair_origin=1
        ;;
      *)
        announce_error "Estratégia de reparo desconhecida para '$verification_label': $repair_strategy"
        return 1
        ;;
    esac
  done

  collect_missing_packages pacman_missing_packages "${repair_pacman_packages[@]}"
  if ((${#pacman_missing_packages[@]} > 0)); then
    announce_detail "Reinstalando itens via pacman..."
    if ! ops_pacman_install_needed "${pacman_missing_packages[@]}"; then
      return 1
    fi
  fi

  if ((${#repair_aur_packages[@]} > 0)); then
    if ! ensure_aur_helper; then
      return 1
    fi

    for aur_package in "${repair_aur_packages[@]}"; do
      if package_is_installed "$aur_package"; then
        continue
      fi

      announce_detail "Reinstalando item via AUR: $aur_package"
      aur_helper_name="$(state_get_aur_helper_name)"
      if ! ops_aur_install_needed "$aur_helper_name" "$aur_package"; then
        return 1
      fi
    done
  fi

  if (( should_repair_codex == 1 )); then
    announce_detail "Reconfigurando o Codex CLI..."
    if ! setup_codex_cli; then
      return 1
    fi
  fi

  if (( should_repair_origin == 1 )); then
    announce_detail "Ajustando o remoto principal do repositório..."
    if ! ensure_repo_origin_remote "$SCRIPT_DIR" "$REPO_SSH_URL"; then
      return 1
    fi
  fi

  if (( should_start_services == 1 )) || ((${#pacman_missing_packages[@]} > 0)); then
    announce_detail "Tentando iniciar os serviços de usuário necessários..."
    start_desktop_user_services || true
  fi

  if desktop_integration_ready && ! has_checkpoint "desktop_integration" && ! mark_checkpoint "desktop_integration"; then
    announce_warning "Não foi possível registrar o checkpoint da integração desktop após a correção automática."
  fi

  verify_installation "$array_name"
  ! state_has_missing_items
}

ensure_final_verification_passed() {
  local array_name="$1"

  if ! state_has_missing_items; then
    return 0
  fi

  if attempt_final_repair_once "$array_name"; then
    return 0
  fi

  announce_error "A verificação final encontrou itens ausentes após a instalação."
  announce_error "Itens ausentes: ${STATE_MISSING_ITEMS[*]}"
  return 1
}
