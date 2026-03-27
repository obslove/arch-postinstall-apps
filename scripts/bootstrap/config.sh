#!/usr/bin/env bash
# shellcheck shell=bash
# shellcheck disable=SC2034

readonly -a BOOTSTRAP_REMOTE_PACKAGES=(
  ca-certificates
  git
  curl
  tar
)
