#!/bin/bash
# lib-activity.sh — shared library for claude-activity hook scripts
# Source this file, don't execute it directly.

DATA_DIR="${CLAUDE_PLUGIN_DATA:-$HOME/.claude}"
ACTIVITY_JS="$DATA_DIR/activity.js"
LOCK_DIR="$DATA_DIR/.activity-lock"
LOCK_PID="$LOCK_DIR/pid"
MAX_ENTRIES=1000
LOCK_TIMEOUT=5

# --- Portable mkdir-based locking ---

acquire_lock() {
  local deadline=$(($(date +%s) + LOCK_TIMEOUT))
  while ! mkdir "$LOCK_DIR" 2>/dev/null; do
    if [ -f "$LOCK_PID" ]; then
      local old_pid
      old_pid=$(cat "$LOCK_PID" 2>/dev/null)
      if [ -n "$old_pid" ] && ! kill -0 "$old_pid" 2>/dev/null; then
        rm -rf "$LOCK_DIR"
        continue
      fi
    fi
    if [ "$(date +%s)" -ge "$deadline" ]; then
      return 1
    fi
    sleep 0.1
  done
  echo $$ > "$LOCK_PID"
  return 0
}

release_lock() {
  rm -rf "$LOCK_DIR"
}

# --- activity.js read/write helpers ---

read_activity_json() {
  if [ ! -f "$ACTIVITY_JS" ]; then
    echo '[]'
    return
  fi
  sed '1s/^window\.ACTIVITY_DATA = //' "$ACTIVITY_JS" | sed '$s/;$//'
}

write_activity_js() {
  local tmp="$ACTIVITY_JS.tmp.$$"
  local json
  json=$(cat)
  printf 'window.ACTIVITY_DATA = %s;\n' "$json" > "$tmp" && mv "$tmp" "$ACTIVITY_JS"
}

# --- Dashboard copy ---

copy_dashboard() {
  if [ -n "$CLAUDE_PLUGIN_ROOT" ] && [ -f "$CLAUDE_PLUGIN_ROOT/dashboard.html" ]; then
    cp -u "$CLAUDE_PLUGIN_ROOT/dashboard.html" "$DATA_DIR/dashboard.html" 2>/dev/null
  fi
}
