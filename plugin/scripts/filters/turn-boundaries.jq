# Find the last user turn in a session JSONL record array.
# Input: array of JSONL records (from tail of session file)
# Output: array of records from the last external user prompt onward

. as $all |
[range(length) | select(
  $all[.].type == "user" and
  $all[.].userType == "external" and
  ($all[.].message.content | type) == "string"
)] | if length == 0 then [] else last as $i | $all[$i:] end
