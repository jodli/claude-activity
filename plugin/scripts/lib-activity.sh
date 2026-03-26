#!/bin/bash
# lib-activity.sh — shared library for claude-activity hook scripts
# Source this file, don't execute it directly.

umask 077

DATA_DIR="${CLAUDE_PLUGIN_DATA:-$HOME/.claude}"
chmod 700 "$DATA_DIR" 2>/dev/null
ACTIVITY_JS="$DATA_DIR/activity.js"
LOCK_DIR="$DATA_DIR/.activity-lock"
LOCK_PID="$LOCK_DIR/pid"
HOOK_LOG="$DATA_DIR/hook.log"
MAX_ENTRIES=1000
MAX_LOG_BYTES=102400
LOCK_TIMEOUT=5

# --- Hook logging ---

log_hook() {
  local msg="$(date -u +%Y-%m-%dT%H:%M:%SZ) [$$] $*"
  echo "$msg" >> "$HOOK_LOG" 2>/dev/null
  # Truncate if over ~100KB: keep last ~80KB
  if [ -f "$HOOK_LOG" ]; then
    local size
    size=$(wc -c < "$HOOK_LOG" 2>/dev/null)
    if [ "${size:-0}" -gt "$MAX_LOG_BYTES" ]; then
      tail -c 81920 "$HOOK_LOG" > "$HOOK_LOG.tmp" 2>/dev/null && mv "$HOOK_LOG.tmp" "$HOOK_LOG" 2>/dev/null
    fi
  fi
}

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

# --- One-time v0.4 migration ---

ACTIVITY_JSONL="$DATA_DIR/activity.jsonl"

maybe_migrate_v04() {
  [ ! -f "$ACTIVITY_JSONL" ] && return 0

  local migrated
  migrated=$(tail -n "$MAX_ENTRIES" "$ACTIVITY_JSONL" | jq -s '
    [.[] | {
      ts, session, project, cwd, prompt,
      response: "",
      effort_total: null,
      duration_s: null,
      slug: null,
      branch: null,
      session_file: (.transcript // null)
    }] | sort_by(.ts) | reverse
  ' 2>/dev/null)

  if [ -n "$migrated" ] && [ "$migrated" != "null" ] && [ "$migrated" != "[]" ]; then
    echo "$migrated" | write_activity_js
  fi

  mv "$ACTIVITY_JSONL" "$ACTIVITY_JSONL.bak" 2>/dev/null
}

# --- Dashboard copy ---

copy_dashboard() {
  if [ -n "$CLAUDE_PLUGIN_ROOT" ] && [ -f "$CLAUDE_PLUGIN_ROOT/dashboard.html" ]; then
    cp -u "$CLAUDE_PLUGIN_ROOT/dashboard.html" "$DATA_DIR/dashboard.html" 2>/dev/null
  fi
}

# --- Project opt-out ---

should_skip_project() {
  local cwd="$1"
  [ -z "$cwd" ] && return 1
  # Resolve worktree path to original project root
  local project_root="${cwd%%/.claude/worktrees/*}"
  [ -f "$project_root/.claude-activity-ignore" ]
}
