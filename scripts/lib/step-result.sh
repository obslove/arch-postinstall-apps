#!/usr/bin/env bash
# shellcheck shell=bash
# shellcheck disable=SC2034

step_result_reset() {
  STEP_RESULT_STATUS=""
  STEP_RESULT_MESSAGE=""
  STEP_RESULT_SUMMARY_PRINTED=0
}

step_result_success() {
  STEP_RESULT_STATUS="success"
  STEP_RESULT_MESSAGE="${1:-}"
}

step_result_skipped() {
  STEP_RESULT_STATUS="skipped"
  STEP_RESULT_MESSAGE="${1:-}"
}

step_result_soft_fail() {
  STEP_RESULT_STATUS="soft_fail"
  STEP_RESULT_MESSAGE="${1:-}"
}

step_result_hard_fail() {
  STEP_RESULT_STATUS="hard_fail"
  STEP_RESULT_MESSAGE="${1:-}"
}
