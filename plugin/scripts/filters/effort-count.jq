# Count tool_use blocks in assistant messages for a turn.
# Input: array of session JSONL records (output of turn-boundaries.jq)
# Output: integer

[.[] | select(.type == "assistant") | .message.content[]? | select(.type == "tool_use")] | length
