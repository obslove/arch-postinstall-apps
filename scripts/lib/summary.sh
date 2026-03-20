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
  local completed_actions=()
  local execution_mode="instalação"
  local changes_applied="sim"
  local version_line
  local github_ssh_status_text
  local desktop_integration_status_text
  local github_component_status
  local desktop_component_status
  local aur_helper_status_text

  if [[ "$CHECK_ONLY" == "1" ]]; then
    execution_mode="verificação"
    changes_applied="não"
  fi

  github_component_status="$(state_get_component_status github_ssh)"
  desktop_component_status="$(state_get_component_status desktop_integration)"
  github_ssh_status_text="$(format_github_ssh_status "$github_component_status")"
  desktop_integration_status_text="$(format_desktop_integration_status "$desktop_component_status")"
  aur_helper_status_text="$(state_get_aur_helper_status)"

  host_name="$(get_host_name)"
  actual_branch="$(get_repo_branch "$SCRIPT_DIR" 2>/dev/null || printf '%s\n' "main")"
  actual_commit="$(current_repo_commit_short "$SCRIPT_DIR")"
  repo_path="$SCRIPT_DIR"
  origin_status="$(current_repo_origin_status "$SCRIPT_DIR")"

  if component_has_checkpoint "codex_cli"; then
    completed_actions+=("codex_cli")
  fi
  if component_has_checkpoint "desktop_integration"; then
    completed_actions+=("desktop_integration")
  fi
  if component_has_checkpoint "github_ssh"; then
    completed_actions+=("github_ssh")
  fi

  close_step_block

  if [[ "$STEP_OUTPUT_ONLY" == "1" ]]; then
    echo
    printf '%s %s\n' "$(style_text "$style_success" "╭─")" "$(style_text "$style_success" "Concluído")"
    print_summary_section "Resultado"
    print_summary_item "Modo:" "$execution_mode"
    print_summary_item "Alterações aplicadas:" "$changes_applied"
    print_summary_item "GitHub SSH:" "$github_ssh_status_text"
    print_summary_item "Integração desktop:" "$desktop_integration_status_text"
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
    print_summary_item "Lista principal via pacman:" "${STATE_MAIN_OFFICIAL_PACKAGES[*]:-nenhum}"
    print_summary_item "Lista principal via AUR:" "${STATE_MAIN_AUR_PACKAGES[*]:-nenhum}"
    print_summary_item "Dependências de suporte:" "${STATE_SUPPORT_PACKAGES[*]:-nenhuma}"
    print_summary_item "Ambiente gráfico:" "${STATE_ENVIRONMENT_PACKAGES[*]:-nenhuma}"
    print_summary_item "Configurações explícitas:" "${completed_actions[*]:-nenhuma}"
    print_summary_item "GitHub SSH esperado:" "$(if github_ssh_expected; then echo sim; else echo não; fi)"
    print_summary_item "GitHub SSH:" "$github_ssh_status_text"
    print_summary_item "Integração desktop:" "$desktop_integration_status_text"
    print_summary_item "Helper AUR:" "$aur_helper_status_text"
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
Itens da lista principal tratados via pacman: ${STATE_MAIN_OFFICIAL_PACKAGES[*]:-nenhum}
Itens da lista principal tratados via AUR: ${STATE_MAIN_AUR_PACKAGES[*]:-nenhum}
Dependências de suporte tratadas: ${STATE_SUPPORT_PACKAGES[*]:-nenhuma}
Dependências do ambiente gráfico tratadas: ${STATE_ENVIRONMENT_PACKAGES[*]:-nenhuma}
Configurações explícitas: ${completed_actions[*]:-nenhuma}
GitHub SSH esperado: $(if github_ssh_expected; then echo sim; else echo não; fi)
GitHub SSH: $github_ssh_status_text
Integração desktop: $desktop_integration_status_text
Helper AUR: $aur_helper_status_text
Falhas pacman: ${STATE_FAILED_OFFICIAL_PACKAGES[*]:-nenhuma}
Falhas AUR: ${STATE_FAILED_AUR_PACKAGES[*]:-nenhuma}
Falhas parciais: ${STATE_SOFT_FAILURES[*]:-nenhuma}
Verificados: ${STATE_VERIFIED_ITEMS[*]:-nenhum}
Ausentes: ${STATE_MISSING_ITEMS[*]:-nenhum}
Versões:
$(if ((${#STATE_VERSION_LINES[@]} == 0)); then echo "- nenhuma"; else printf '%s\n' "${STATE_VERSION_LINES[@]/#/- }"; fi)
Checkpoints:
- codex_cli: $(if component_has_checkpoint "codex_cli"; then echo concluido; else echo pendente; fi)
- desktop_integration: $(if component_has_checkpoint "desktop_integration"; then echo concluido; else echo pendente; fi)
- github_ssh: $(if component_has_checkpoint "github_ssh"; then echo concluido; else echo pendente; fi)
EOF

  if [[ "$SCRIPT_DIR" != "$INSTALL_DIR" ]]; then
    printf 'Clone gerenciado: %s\n' "$INSTALL_DIR" >>"$SUMMARY_FILE"
  fi
}
