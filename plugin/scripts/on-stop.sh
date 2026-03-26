#!/bin/bash
# on-stop.sh — Stop hook
# Enriches the most recent in-progress entry with response, effort, and duration.

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/lib-activity.sh"
FILTERS_DIR="$SCRIPT_DIR/filters"

INPUT=$(cat)

# Guard against infinite loops — MUST be first check
STOP_HOOK_ACTIVE=$(echo "$INPUT" | jq -r '.stop_hook_active // false')
[ "$STOP_HOOK_ACTIVE" = "true" ] && exit 0

SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // empty')
CWD=$(echo "$INPUT" | jq -r '.cwd // empty')
TRANSCRIPT_PATH=$(echo "$INPUT" | jq -r '.transcript_path // empty')
LAST_MSG=$(echo "$INPUT" | jq -r '.last_assistant_message // empty')

[ -z "$SESSION_ID" ] && exit 0

# Project opt-out
if should_skip_project "$CWD"; then
  exit 0
fi

# --- Process response text ---

process_response() {
  local text="$1"
  [ -z "$text" ] && echo "" && return

  # Replace code fences with placeholder
  text=$(echo "$text" | awk '
    /^```/ {
      if (in_fence) {
        printf "[code block: %d lines]\n", fence_lines
        in_fence = 0; fence_lines = 0
      } else {
        in_fence = 1; fence_lines = 0
      }
      next
    }
    in_fence { fence_lines++; next }
    { print }
  ')

  # Strip markdown formatting
  text=$(echo "$text" | sed \
    -e 's/^#\{1,6\} //' \
    -e 's/\*\*\([^*]*\)\*\*/\1/g' \
    -e 's/\*\([^*]*\)\*/\1/g' \
    -e 's/`\([^`]*\)`/\1/g')

  # Cap at ~500 chars
  if [ ${#text} -gt 500 ]; then
    text="${text:0:497}..."
  fi

  echo "$text"
}

RESPONSE=$(process_response "$LAST_MSG")

# --- Extract effort and duration from session JSONL ---

EFFORT_TOTAL=0
DURATION_S=0

if [ -n "$TRANSCRIPT_PATH" ] && [ -f "$TRANSCRIPT_PATH" ]; then
  # Try tail first (fast), fall back to full file for heavy agent sessions
  TURN_DATA=$(tail -500 "$TRANSCRIPT_PATH" | jq -s -f "$FILTERS_DIR/turn-boundaries.jq" 2>/dev/null)

  if [ -z "$TURN_DATA" ] || [ "$TURN_DATA" = "[]" ]; then
    TURN_DATA=$(jq -s -f "$FILTERS_DIR/turn-boundaries.jq" "$TRANSCRIPT_PATH" 2>/dev/null)
  fi

  if [ -n "$TURN_DATA" ] && [ "$TURN_DATA" != "[]" ]; then
    EFFORT_TOTAL=$(echo "$TURN_DATA" | jq -f "$FILTERS_DIR/effort-count.jq" 2>/dev/null)
    [ -z "$EFFORT_TOTAL" ] || [ "$EFFORT_TOTAL" = "null" ] && EFFORT_TOTAL=0

    FIRST_TS=$(echo "$TURN_DATA" | jq -r '.[0].timestamp // empty' 2>/dev/null)
    LAST_TS=$(echo "$TURN_DATA" | jq -r '.[-1].timestamp // empty' 2>/dev/null)

    if [ -n "$FIRST_TS" ] && [ -n "$LAST_TS" ]; then
      if date -d "2000-01-01" +%s >/dev/null 2>&1; then
        FIRST_EPOCH=$(date -d "$FIRST_TS" +%s 2>/dev/null)
        LAST_EPOCH=$(date -d "$LAST_TS" +%s 2>/dev/null)
      else
        FIRST_EPOCH=$(date -j -f "%Y-%m-%dT%H:%M:%S" "${FIRST_TS%%.*}" +%s 2>/dev/null)
        LAST_EPOCH=$(date -j -f "%Y-%m-%dT%H:%M:%S" "${LAST_TS%%.*}" +%s 2>/dev/null)
      fi

      if [ -n "$FIRST_EPOCH" ] && [ -n "$LAST_EPOCH" ]; then
        DURATION_S=$((LAST_EPOCH - FIRST_EPOCH))
        [ "$DURATION_S" -lt 0 ] && DURATION_S=0
      fi
    fi
  fi
fi

# --- Update activity.js in background ---
{
  acquire_lock || exit 0

  DATA=$(read_activity_json)

  UPDATED=$(echo "$DATA" | jq \
    --arg sid "$SESSION_ID" \
    --arg response "$RESPONSE" \
    --argjson effort "${EFFORT_TOTAL:-0}" \
    --argjson duration "${DURATION_S:-0}" \
    '
    reduce range(length) as $i (
      {arr: ., primary_filled: false};

      if .arr[$i].session == $sid and .arr[$i].response == null then
        if .primary_filled then
          # Catch-up: stale entry from missed silent tool stop
          .arr[$i].response = ""
        else
          # Primary: most recent null entry gets real data
          .arr[$i].response = $response |
          .arr[$i].effort_total = $effort |
          .arr[$i].duration_s = $duration |
          .primary_filled = true
        end
      else .
      end
    ) | .arr
    ')

  echo "$UPDATED" | write_activity_js
  release_lock
} &

exit 0
