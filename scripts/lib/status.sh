#!/usr/bin/env bash
# shellcheck shell=bash

readonly STATUS_PENDING="pending"
readonly STATUS_DONE="done"
readonly STATUS_SKIPPED_READY="skipped_ready"
readonly STATUS_SKIPPED_DISABLED="skipped_disabled"
readonly STATUS_SKIPPED_DECLINED="skipped_declined"
readonly STATUS_SOFT_FAILED="soft_failed"
readonly STATUS_HARD_FAILED="hard_failed"

format_github_ssh_status() {
  case "${1:-}" in
    "$STATUS_DONE")
      printf '%s\n' "concluída"
      ;;
    "$STATUS_SKIPPED_DISABLED")
      printf '%s\n' "ignorada por configuração"
      ;;
    "$STATUS_SKIPPED_READY")
      printf '%s\n' "ignorada por já estar pronta"
      ;;
    "$STATUS_SKIPPED_DECLINED")
      printf '%s\n' "ignorada por confirmação negada"
      ;;
    "$STATUS_SOFT_FAILED")
      printf '%s\n' "ignorada por falha"
      ;;
    "$STATUS_PENDING")
      printf '%s\n' "pendente"
      ;;
    "$STATUS_HARD_FAILED")
      printf '%s\n' "falhou"
      ;;
    *)
      printf '%s\n' "${1:-indisponível}"
      ;;
  esac
}

format_desktop_integration_status() {
  case "${1:-}" in
    "$STATUS_DONE")
      printf '%s\n' "concluída"
      ;;
    "$STATUS_SKIPPED_READY")
      printf '%s\n' "ignorada por já estar pronta"
      ;;
    "$STATUS_PENDING")
      printf '%s\n' "pendente"
      ;;
    "$STATUS_HARD_FAILED")
      printf '%s\n' "falhou"
      ;;
    *)
      printf '%s\n' "${1:-indisponível}"
      ;;
  esac
}
