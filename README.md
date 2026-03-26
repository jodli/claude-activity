# claude-activity

A Claude Code plugin that logs your prompts and shows them in a local dashboard.

The problem: you work across multiple projects, have a meeting, come back, and can't remember which sessions you were in or what you were doing. `claude --resume` exists but doesn't give you a cross-project overview.

## What it looks like

![Session hover-highlight showing two concurrent web-app sessions](assets/session-hover-highlight.gif)

The dashboard shows:

- **Last Touched** — one line per project, most recent first, with relative time ("2h ago"). Hide projects you don't need, restore them anytime.
- **Timeline** — prompts grouped by day with timestamps and project names
- **Peek popover** — click any entry to see the full prompt, Claude's response, effort (tool calls), and duration
- **Session indicators** — colored dots and left-border stripes show which prompts belong to the same session. Hover any entry to highlight all prompts from that session while dimming the rest.
- **In-progress** — pulsing green dot when Claude is still working; orange dot for stale entries where the session may have ended
- **Filter pills** — click a project to filter, or use the search box
- **Today / 7 Days toggle** — default shows today, switch to see the week
- **Action verb highlighting** — `fix` is red, `add` is green, `research` is blue, `refactor` is orange
- **5 themes** — Tokyo Night, Catppuccin Mocha, Kanagawa, Catppuccin Latte, Rose Pine Dawn
- **Keyboard shortcuts** — `j`/`k` to navigate, `/` to search, `r` to resume, `?` for help
- **Resume button** — copies `cd "<project>" && claude --resume "<session>"` to clipboard

Noise is filtered out automatically: short confirmations (`ja`, `ok`, `yes`), empty prompts, and bare slash commands are skipped.

## Install

1. In Claude Code, run `/plugins`
2. Select **Add Marketplace** and enter `git@github.com:jodli/claude-activity.git`
3. Install the `claude-activity` plugin
4. Run `/reload-plugins` to activate

## Usage

Once installed, every prompt you type in Claude Code gets logged automatically.

Open the dashboard:

```
/claude-activity:dashboard
```

Or open the HTML file directly in your browser:

```
~/.claude/plugins/data/claude-activity-claude-activity/dashboard.html
```

The dashboard auto-refreshes every 10 seconds.

## How it works

1. `UserPromptSubmit` hook fires on every prompt — `on-prompt.sh` creates an entry with `response: null` (in-progress) in `activity.js`
2. `Stop` hook fires after Claude responds — `on-stop.sh` fills in the response text, effort count, and duration
3. `dashboard.html` loads `activity.js` via a `<script>` tag and renders everything client-side

Data is stored at `~/.claude/plugins/data/claude-activity-claude-activity/`. Hook diagnostics are logged to `hook.log` in the same directory.

No server, no build step, no dependencies beyond `jq`.

## Opting out

To exclude a project from activity logging, create an empty file in the project root:

```
touch .claude-activity-ignore
```

This also works for worktree paths. Opt-out is not retroactive — existing entries for the project remain in the dashboard.

## Requirements

- Claude Code
- `jq` >= 1.6

## License

MIT
