#!/bin/bash
# Claude Code UserPromptSubmit hook
# Logs every user prompt to activity.jsonl and regenerates activity.js

DATA_DIR="${CLAUDE_PLUGIN_DATA:-$HOME/.claude}"
ACTIVITY_LOG="$DATA_DIR/activity.jsonl"

# Read hook payload from stdin
INPUT=$(cat)

# Extract fields
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // empty')
PROMPT=$(echo "$INPUT" | jq -r '.prompt // empty')
CWD=$(echo "$INPUT" | jq -r '.cwd // empty')
TRANSCRIPT=$(echo "$INPUT" | jq -r '.transcript_path // empty')

# Skip noise: empty, task notifications, short prompts (< 3 words), bare slash commands
[ -z "$PROMPT" ] && exit 0
echo "$PROMPT" | grep -q '^<task-notification>' && exit 0
WORD_COUNT=$(echo "$PROMPT" | wc -w)
[ "$WORD_COUNT" -lt 3 ] && exit 0

# Extract project name from cwd (strip worktree suffix if present)
PROJECT=$(basename "${CWD%%/.claude/worktrees/*}")

# Append to JSONL log
jq -n -c \
  --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  --arg session "$SESSION_ID" \
  --arg project "$PROJECT" \
  --arg cwd "$CWD" \
  --arg prompt "$PROMPT" \
  --arg transcript "$TRANSCRIPT" \
  '{ts: $ts, session: $session, project: $project, cwd: $cwd, prompt: $prompt, transcript: $transcript}' \
  >> "$ACTIVITY_LOG"

# Regenerate activity.js (async, don't block Claude)
export CLAUDE_PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT}"
export CLAUDE_PLUGIN_DATA="${CLAUDE_PLUGIN_DATA}"
flock -n "$DATA_DIR/.dashboard-lock" "${CLAUDE_PLUGIN_ROOT}/scripts/generate-dashboard.sh" &

exit 0
