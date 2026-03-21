#!/usr/bin/env bash
# shellcheck shell=bash

readonly COMPONENT_OUTCOME_PENDING="pending"
readonly COMPONENT_OUTCOME_CHANGED="changed"
readonly COMPONENT_OUTCOME_REUSED="reused"
readonly COMPONENT_OUTCOME_DISABLED="disabled"
readonly COMPONENT_OUTCOME_DECLINED="declined"
readonly COMPONENT_OUTCOME_SOFT_FAILED="soft_failed"
readonly COMPONENT_OUTCOME_FAILED="failed"
readonly COMPONENT_OUTCOME_FALLBACK_REUSED="fallback_reused"

component_outcome_changed_flag() {
  case "${1:-}" in
    "$COMPONENT_OUTCOME_CHANGED")
      printf '%s\n' "1"
      ;;
    *)
      printf '%s\n' "0"
      ;;
  esac
}

component_outcome_counts_as_ready() {
  case "${1:-}" in
    "$COMPONENT_OUTCOME_CHANGED"|"$COMPONENT_OUTCOME_REUSED"|"$COMPONENT_OUTCOME_FALLBACK_REUSED")
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

component_outcome_step_status() {
  case "${1:-}" in
    "$COMPONENT_OUTCOME_CHANGED"|"$COMPONENT_OUTCOME_PENDING")
      printf '%s\n' "success"
      ;;
    "$COMPONENT_OUTCOME_REUSED"|"$COMPONENT_OUTCOME_DISABLED"|"$COMPONENT_OUTCOME_DECLINED"|"$COMPONENT_OUTCOME_FALLBACK_REUSED")
      printf '%s\n' "skipped"
      ;;
    "$COMPONENT_OUTCOME_SOFT_FAILED")
      printf '%s\n' "soft_fail"
      ;;
    "$COMPONENT_OUTCOME_FAILED")
      printf '%s\n' "hard_fail"
      ;;
    *)
      return 1
      ;;
  esac
}

format_github_ssh_status() {
  case "${1:-}" in
    "$COMPONENT_OUTCOME_CHANGED")
      printf '%s\n' "concluída"
      ;;
    "$COMPONENT_OUTCOME_DISABLED")
      printf '%s\n' "ignorada por configuração"
      ;;
    "$COMPONENT_OUTCOME_REUSED")
      printf '%s\n' "ignorada por já estar pronta"
      ;;
    "$COMPONENT_OUTCOME_DECLINED")
      printf '%s\n' "ignorada por confirmação negada"
      ;;
    "$COMPONENT_OUTCOME_SOFT_FAILED")
      printf '%s\n' "ignorada por falha"
      ;;
    "$COMPONENT_OUTCOME_PENDING")
      printf '%s\n' "pendente"
      ;;
    "$COMPONENT_OUTCOME_FAILED")
      printf '%s\n' "falhou"
      ;;
    *)
      printf '%s\n' "${1:-indisponível}"
      ;;
  esac
}

format_desktop_integration_status() {
  case "${1:-}" in
    "$COMPONENT_OUTCOME_CHANGED")
      printf '%s\n' "concluída"
      ;;
    "$COMPONENT_OUTCOME_REUSED")
      printf '%s\n' "ignorada por já estar pronta"
      ;;
    "$COMPONENT_OUTCOME_PENDING")
      printf '%s\n' "pendente"
      ;;
    "$COMPONENT_OUTCOME_FAILED")
      printf '%s\n' "falhou"
      ;;
    *)
      printf '%s\n' "${1:-indisponível}"
      ;;
  esac
}
