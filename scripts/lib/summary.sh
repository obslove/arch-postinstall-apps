#!/usr/bin/env bash
# shellcheck shell=bash
# shellcheck source-path=SCRIPTDIR
# shellcheck source=scripts/lib/shellcheck-runtime.sh
# shellcheck source=scripts/lib/status.sh
# shellcheck source=scripts/lib/components.sh
# shellcheck source=scripts/lib/runtime-state.sh

if false; then
  source "$SCRIPT_DIR/scripts/lib/shellcheck-runtime.sh"
  source "$SCRIPT_DIR/scripts/lib/status.sh"
  source "$SCRIPT_DIR/scripts/lib/components.sh"
  source "$SCRIPT_DIR/scripts/lib/runtime-state.sh"
fi

print_summary() {
  local host_name
  local actual_branch
  local actual_commit
  local repo_path
  local origin_status="indisponível"
  local checkpoint_component_ids=()
  local status_component_ids=()
  local completed_actions=()
  local execution_mode="instalação"
  local changes_applied="não"
  local version_line
  local component_id
  local component_label
  local component_status_text

  if [[ "$CHECK_ONLY" == "1" ]]; then
    execution_mode="verificação"
    changes_applied="não"
  elif report_has_changes; then
    changes_applied="sim"
  fi

  mapfile -t checkpoint_component_ids < <(component_checkpoint_summary_ids)
  mapfile -t status_component_ids < <(component_summary_status_ids)

  host_name="$(get_host_name)"
  actual_branch="$(get_repo_branch "$SCRIPT_DIR" 2>/dev/null || printf '%s\n' "main")"
  actual_commit="$(current_repo_commit_short "$SCRIPT_DIR")"
  repo_path="$SCRIPT_DIR"
  origin_status="$(current_repo_origin_status "$SCRIPT_DIR")"

  for component_id in "${checkpoint_component_ids[@]}"; do
    if component_has_checkpoint "$component_id"; then
      completed_actions+=("$component_id")
    fi
  done

  close_step_block

  if [[ "$STEP_OUTPUT_ONLY" == "1" ]]; then
    echo
    printf '%s %s\n' "$(style_text "$style_success" "╭─")" "$(style_text "$style_success" "Concluído")"
    print_summary_section "Resultado"
    print_summary_item "Modo:" "$execution_mode"
    print_summary_item "Alterações aplicadas:" "$changes_applied"
    for component_id in "${status_component_ids[@]}"; do
      component_label="$(component_summary_label "$component_id")"
      component_status_text="$(component_summary_status_text "$component_id")"
      print_summary_item "$component_label:" "$component_status_text"
    done
    print_summary_section "Repositório"
    print_summary_item "Commit:" "$actual_commit"
    print_summary_section "Arquivos"
    print_summary_item "Log:" "$LOG_FILE"
    print_summary_item "Resumo:" "$SUMMARY_FILE"
    echo "│"
    style_text "$style_muted" "╰─ Fim"
    printf '\n'
  else
    echo
    printf '%s %s\n' "$(style_text "$style_success" "╭─")" "$(style_text "$style_success" "Concluído")"
    print_summary_section "Arquivos"
    print_summary_item "Log:" "$LOG_FILE"
    print_summary_item "Resumo:" "$SUMMARY_FILE"
    print_summary_section "Estado"
    print_summary_item "Modo:" "$execution_mode"
    print_summary_item "Alterações aplicadas:" "$changes_applied"
    print_summary_item "Hostname:" "$host_name"
    print_summary_item "Repositório:" "$repo_path"
    print_summary_item "Branch:" "$actual_branch"
    print_summary_item "Commit:" "$actual_commit"
    print_summary_item "Origin:" "$origin_status"
    print_summary_section "Pacotes e configuração"
    print_summary_item "Lista principal via pacman:" "${REPORT_REQUESTED_MAIN_OFFICIAL_PACKAGES[*]:-nenhum}"
    print_summary_item "Alterados via pacman:" "${REPORT_CHANGED_MAIN_OFFICIAL_PACKAGES[*]:-nenhum}"
    print_summary_item "Lista principal via AUR:" "${REPORT_REQUESTED_MAIN_AUR_PACKAGES[*]:-nenhum}"
    print_summary_item "Alterados via AUR:" "${REPORT_CHANGED_MAIN_AUR_PACKAGES[*]:-nenhum}"
    print_summary_item "Suporte alterado:" "${REPORT_CHANGED_SUPPORT_PACKAGES[*]:-nenhuma}"
    print_summary_item "Suporte reutilizado:" "${REPORT_REUSED_SUPPORT_PACKAGES[*]:-nenhuma}"
    print_summary_item "Ambiente alterado:" "${REPORT_CHANGED_ENVIRONMENT_PACKAGES[*]:-nenhuma}"
    print_summary_item "Ambiente reutilizado:" "${REPORT_REUSED_ENVIRONMENT_PACKAGES[*]:-nenhuma}"
    print_summary_item "Configurações explícitas:" "${completed_actions[*]:-nenhuma}"
    print_summary_item "GitHub SSH esperado:" "$(if github_ssh_expected; then echo sim; else echo não; fi)"
    for component_id in "${status_component_ids[@]}"; do
      component_label="$(component_summary_label "$component_id")"
      component_status_text="$(component_summary_status_text "$component_id")"
      print_summary_item "$component_label:" "$component_status_text"
    done
    print_summary_section "Verificação"
    print_summary_item "Falhas pacman:" "${STATE_FAILED_OFFICIAL_PACKAGES[*]:-nenhuma}"
    print_summary_item "Falhas AUR:" "${STATE_FAILED_AUR_PACKAGES[*]:-nenhuma}"
    print_summary_item "Falhas parciais:" "${STATE_SOFT_FAILURES[*]:-nenhuma}"
    print_summary_item "Verificados:" "${STATE_VERIFIED_ITEMS[*]:-nenhum}"
    print_summary_item "Ausentes:" "${STATE_MISSING_ITEMS[*]:-nenhum}"
    if ((${#STATE_VERSION_LINES[@]} == 0)); then
      print_summary_item "Versões:" "nenhuma"
    else
      print_summary_section "Versões"
      for version_line in "${STATE_VERSION_LINES[@]}"; do
        echo "│    $(style_text "$style_detail" "•") $version_line"
      done
    fi
    echo "│"
    style_text "$style_muted" "╰─ Fim"
    printf '\n'
  fi

  mkdir -p "$(dirname "$SUMMARY_FILE")"
  cat >"$SUMMARY_FILE" <<EOF
Data: $(date '+%Y-%m-%d %H:%M:%S %z')
Modo: $execution_mode
Alterações aplicadas: $changes_applied
Log: $LOG_FILE
Hostname: $host_name
Repositório: $repo_path
Branch: $actual_branch
Commit: $actual_commit
Origin: $origin_status
Itens da lista principal declarados via pacman: ${REPORT_REQUESTED_MAIN_OFFICIAL_PACKAGES[*]:-nenhum}
Itens da lista principal alterados via pacman: ${REPORT_CHANGED_MAIN_OFFICIAL_PACKAGES[*]:-nenhum}
Itens da lista principal declarados via AUR: ${REPORT_REQUESTED_MAIN_AUR_PACKAGES[*]:-nenhum}
Itens da lista principal alterados via AUR: ${REPORT_CHANGED_MAIN_AUR_PACKAGES[*]:-nenhum}
Dependências de suporte alteradas: ${REPORT_CHANGED_SUPPORT_PACKAGES[*]:-nenhuma}
Dependências de suporte reutilizadas: ${REPORT_REUSED_SUPPORT_PACKAGES[*]:-nenhuma}
Dependências do ambiente gráfico alteradas: ${REPORT_CHANGED_ENVIRONMENT_PACKAGES[*]:-nenhuma}
Dependências do ambiente gráfico reutilizadas: ${REPORT_REUSED_ENVIRONMENT_PACKAGES[*]:-nenhuma}
Configurações explícitas: ${completed_actions[*]:-nenhuma}
GitHub SSH esperado: $(if github_ssh_expected; then echo sim; else echo não; fi)
$(for component_id in "${status_component_ids[@]}"; do
    component_label="$(component_summary_label "$component_id")"
    component_status_text="$(component_summary_status_text "$component_id")"
    printf '%s: %s\n' "$component_label" "$component_status_text"
  done)
Falhas pacman: ${STATE_FAILED_OFFICIAL_PACKAGES[*]:-nenhuma}
Falhas AUR: ${STATE_FAILED_AUR_PACKAGES[*]:-nenhuma}
Falhas parciais: ${STATE_SOFT_FAILURES[*]:-nenhuma}
Verificados: ${STATE_VERIFIED_ITEMS[*]:-nenhum}
Ausentes: ${STATE_MISSING_ITEMS[*]:-nenhum}
Versões:
$(if ((${#STATE_VERSION_LINES[@]} == 0)); then echo "- nenhuma"; else printf '%s\n' "${STATE_VERSION_LINES[@]/#/- }"; fi)
Checkpoints:
$(for component_id in "${checkpoint_component_ids[@]}"; do
    printf -- '- %s: %s\n' \
      "$component_id" \
      "$(if component_has_checkpoint "$component_id"; then echo concluido; else echo pendente; fi)"
  done)
EOF

  if [[ "$SCRIPT_DIR" != "$INSTALL_DIR" ]]; then
    printf 'Clone gerenciado: %s\n' "$INSTALL_DIR" >>"$SUMMARY_FILE"
  fi
}
