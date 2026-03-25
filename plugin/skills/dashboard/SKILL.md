---
disable-model-invocation: true
---

# Open Activity Dashboard

Opens the claude-activity dashboard in your default browser.

## Instructions

Run this shell command to open the dashboard:

```bash
FILE="${CLAUDE_PLUGIN_DATA}/dashboard.html"
if [ ! -f "$FILE" ]; then
  echo "Dashboard not found at $FILE — send a prompt first to generate it."
else
  case "$(uname -s)" in
    Linux*)  xdg-open "$FILE" 2>/dev/null ;;
    Darwin*) open "$FILE" ;;
    MINGW*|MSYS*|CYGWIN*) start "" "$FILE" ;;
  esac
  echo "Opened activity dashboard."
fi
```
