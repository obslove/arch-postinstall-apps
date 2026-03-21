#!/usr/bin/env bash
# shellcheck shell=bash

checkpoint_file() {
  printf '%s/checkpoints/%s.done\n' "$STATE_DIR" "$1"
}

has_checkpoint() {
  [[ -f "$(checkpoint_file "$1")" ]]
}

mark_checkpoint() {
  mkdir -p "$STATE_DIR/checkpoints"
  touch "$(checkpoint_file "$1")"
}

register_cleanup_path() {
  cleanup_paths+=("$1")
}

acquire_lock() {
  local existing_pid=""

  if [[ "$LOCK_HELD" == "1" ]]; then
    return
  fi

  mkdir -p "$STATE_DIR"
  if mkdir "$LOCK_DIR" 2>/dev/null; then
    printf '%s\n' "$$" >"$LOCK_DIR/pid"
    register_cleanup_path "$LOCK_DIR"
    export POSTINSTALL_LOCK_HELD=1
    LOCK_HELD=1
    return
  fi

  if [[ -f "$LOCK_DIR/pid" ]]; then
    existing_pid="$(<"$LOCK_DIR/pid")"
  fi

  if [[ -z "$existing_pid" ]] || ! kill -0 "$existing_pid" 2>/dev/null; then
    announce_warning "Foi detectado um lock órfão. Limpando a execução anterior."
    rm -rf -- "$LOCK_DIR"
    if mkdir "$LOCK_DIR" 2>/dev/null; then
      printf '%s\n' "$$" >"$LOCK_DIR/pid"
      register_cleanup_path "$LOCK_DIR"
      export POSTINSTALL_LOCK_HELD=1
      LOCK_HELD=1
      return
    fi
  fi

  announce_error "Já existe outra execução do script em andamento."
  if [[ -f "$LOCK_DIR/pid" ]]; then
    announce_error "PID atual do lock: $(<"$LOCK_DIR/pid")"
  fi
  exit 1
}

cleanup() {
  local path

  for path in "${cleanup_paths[@]}"; do
    [[ -n "$path" ]] || continue
    rm -rf -- "$path"
  done
}
