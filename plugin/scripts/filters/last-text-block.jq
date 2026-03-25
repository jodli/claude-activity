# Extract the last text block from assistant messages in a turn.
# Input: array of session JSONL records (output of turn-boundaries.jq)
# Output: string

[.[] | select(.type == "assistant") | .message.content[]? | select(.type == "text") | .text] | last // ""
