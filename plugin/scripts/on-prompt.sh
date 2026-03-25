#!/bin/bash
# on-prompt.sh — UserPromptSubmit hook
# Creates a new activity entry with response: null, writes to activity.js

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/lib-activity.sh"

INPUT=$(cat)

SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // empty')
PROMPT=$(echo "$INPUT" | jq -r '.prompt // empty')
CWD=$(echo "$INPUT" | jq -r '.cwd // empty')
TRANSCRIPT_PATH=$(echo "$INPUT" | jq -r '.transcript_path // empty')

# Noise filtering (carried from v0.4)
[ -z "$PROMPT" ] && exit 0
echo "$PROMPT" | grep -q '^<task-notification>' && exit 0
echo "$PROMPT" | grep -q '^<command-message>' && exit 0
WORD_COUNT=$(echo "$PROMPT" | wc -w)
[ "$WORD_COUNT" -lt 3 ] && exit 0

# Extract project name (strip worktree suffix if present)
PROJECT=$(basename "${CWD%%/.claude/worktrees/*}")

# Extract branch and slug from last line of session JSONL (fast, O(1))
BRANCH=""
SLUG=""
if [ -n "$TRANSCRIPT_PATH" ] && [ -f "$TRANSCRIPT_PATH" ]; then
  BRANCH=$(tail -1 "$TRANSCRIPT_PATH" | jq -r '.gitBranch // empty' 2>/dev/null)
  SLUG=$(tail -1 "$TRANSCRIPT_PATH" | jq -r '.slug // empty' 2>/dev/null)
fi

NEW_ENTRY=$(jq -n -c \
  --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  --arg session "$SESSION_ID" \
  --arg project "$PROJECT" \
  --arg cwd "$CWD" \
  --arg prompt "$PROMPT" \
  --arg branch "$BRANCH" \
  --arg slug "$SLUG" \
  --arg session_file "$TRANSCRIPT_PATH" \
  '{
    ts: $ts,
    session: $session,
    project: $project,
    cwd: $cwd,
    prompt: $prompt,
    response: null,
    effort_total: null,
    duration_s: null,
    slug: (if $slug == "" then null else $slug end),
    branch: (if $branch == "" then null else $branch end),
    session_file: (if $session_file == "" then null else $session_file end)
  }')

# Write to activity.js in background (don't block Claude)
{
  acquire_lock || exit 0

  DATA=$(read_activity_json)
  echo "$DATA" | jq --argjson entry "$NEW_ENTRY" --argjson max "$MAX_ENTRIES" \
    '[$entry] + . | .[:$max]' | write_activity_js

  copy_dashboard
  release_lock
} &

exit 0
