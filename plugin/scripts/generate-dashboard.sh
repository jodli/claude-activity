#!/bin/bash
# Exports activity.jsonl as a JS file for the dashboard to consume.
# Called by log-prompt.sh after each new entry.

DATA_DIR="${CLAUDE_PLUGIN_DATA:-$HOME/.claude}"
ACTIVITY_LOG="$DATA_DIR/activity.jsonl"
ACTIVITY_JS="$DATA_DIR/activity.js"
MAX_ENTRIES=1000

[ ! -f "$ACTIVITY_LOG" ] && exit 0

# Keep dashboard.html in data dir (stable path, survives plugin updates)
cp -u "${CLAUDE_PLUGIN_ROOT}/dashboard.html" "$DATA_DIR/dashboard.html" 2>/dev/null

DATA=$(tail -n "$MAX_ENTRIES" "$ACTIVITY_LOG" | jq -s 'sort_by(.ts) | reverse')
echo "window.ACTIVITY_DATA = ${DATA};" > "$ACTIVITY_JS.tmp" \
  && mv "$ACTIVITY_JS.tmp" "$ACTIVITY_JS"
