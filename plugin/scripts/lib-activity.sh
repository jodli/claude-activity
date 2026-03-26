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

# --- jq validation ---

validate_jq() {
  if ! command -v jq >/dev/null 2>&1; then
    log_hook "FATAL: jq not found in PATH"
    return 1
  fi
  local jq_ver
  jq_ver=$(jq --version 2>/dev/null | sed 's/[^0-9.]//g')
  if [ -z "$jq_ver" ]; then
    log_hook "WARN: could not determine jq version"
    return 0
  fi
  local major minor
  major="${jq_ver%%.*}"
  minor="${jq_ver#*.}"
  if [ "${major:-0}" -lt 1 ] || { [ "${major:-0}" -eq 1 ] && [ "${minor:-0}" -lt 6 ]; }; then
    log_hook "FATAL: jq $jq_ver is below minimum 1.6"
    return 1
  fi
  return 0
}

# --- Portable timestamp conversion ---

ts_to_epoch() {
  local ts="$1"
  [ -z "$ts" ] && return 1
  # Try GNU date first, then BSD date
  if date -d "2000-01-01" +%s >/dev/null 2>&1; then
    date -d "$ts" +%s 2>/dev/null
  else
    date -j -f "%Y-%m-%dT%H:%M:%S" "${ts%%.*}" +%s 2>/dev/null
  fi
}

# --- Portable mkdir-based locking ---

LOCK_MAX_AGE=60

acquire_lock() {
  local deadline=$(($(date +%s) + LOCK_TIMEOUT))
  while ! mkdir "$LOCK_DIR" 2>/dev/null; do
    # Stale lock: process dead
    if [ -f "$LOCK_PID" ]; then
      local old_pid
      old_pid=$(cat "$LOCK_PID" 2>/dev/null)
      if [ -n "$old_pid" ] && ! kill -0 "$old_pid" 2>/dev/null; then
        log_hook "WARN: removing stale lock (dead pid $old_pid)"
        rm -rf "$LOCK_DIR"
        continue
      fi
    fi
    # Stale lock: older than LOCK_MAX_AGE (handles PID recycling after reboot)
    if [ -d "$LOCK_DIR" ]; then
      local lock_age
      lock_age=$(find "$LOCK_DIR" -maxdepth 0 -mmin +1 2>/dev/null)
      if [ -n "$lock_age" ]; then
        log_hook "WARN: removing stale lock (older than ${LOCK_MAX_AGE}s)"
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
  local raw
  raw=$(sed '1s/^window\.ACTIVITY_DATA = //' "$ACTIVITY_JS" | sed '$s/;$//')
  # Validate it's a JSON array; recover if corrupted
  if echo "$raw" | jq -e 'type == "array"' >/dev/null 2>&1; then
    echo "$raw"
  else
    log_hook "WARN: activity.js corrupted, recovering to []"
    echo '[]'
  fi
}

write_activity_js() {
  local tmp="$ACTIVITY_JS.tmp.$$"
  local json
  json=$(cat)
  # Validate: never write empty or non-array data
  if [ -z "$json" ] || ! echo "$json" | jq -e 'type == "array"' >/dev/null 2>&1; then
    log_hook "ERROR: refusing to write invalid data to activity.js"
    rm -f "$tmp" 2>/dev/null
    return 1
  fi
  printf 'window.ACTIVITY_DATA = %s;\n' "$json" > "$tmp" && mv "$tmp" "$ACTIVITY_JS"
}

cleanup_stale_tmp() {
  find "$DATA_DIR" -maxdepth 1 -name "activity.js.tmp.*" -mmin +1 -delete 2>/dev/null
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
  local src="$CLAUDE_PLUGIN_ROOT/dashboard.html"
  local dst="$DATA_DIR/dashboard.html"
  if [ -n "$CLAUDE_PLUGIN_ROOT" ] && [ -f "$src" ]; then
    # Portable cp -u: only copy if source is newer (or dest missing)
    if [ ! -f "$dst" ] || [ "$src" -nt "$dst" ]; then
      cp "$src" "$dst" 2>/dev/null
    fi
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
