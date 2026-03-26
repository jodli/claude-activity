# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.1/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2026-03-26

### Added

- Hook logging: `hook.log` with timestamps, PID, and 100KB auto-truncation
- `.claude-activity-ignore` opt-out: skip logging when file exists in project root
- Error handling: jq version validation (>= 1.6), corrupt `activity.js` recovery, write guards
- Peek popover focus management: focus moves into popover on open, returns to entry on close
- New tests for resume quoting, focus management, no-results state

### Changed

- Resume clipboard command now quotes paths to prevent shell injection
- File permissions hardened: umask 077, chmod 700 on data directory
- Lock timeout and jq errors now logged to hook.log
- `cp -u` replaced with portable `test -nt` alternative (macOS compatibility)
- `grep -oP` replaced with `sed` in jq version check (macOS compatibility)
- Date parsing consolidated into `ts_to_epoch()` utility (GNU/BSD portable)
- Lock-age fallback: locks older than 60s removed regardless of PID
- Stale `.tmp` files cleaned up on each invocation

## [0.8.0] - 2026-03-26

### Changed

- Dashboard rewritten from scratch — same features, clean foundation
- All rendering converted from innerHTML to `el()` DOM builder (XSS-safe by construction)
- CSS consolidated: `--font-mono`, `--font-body`, `--transition-fast` custom properties, `.truncate` utility
- JS restructured into 7 sections: Constants, State, DOM Refs, Utilities, Rendering, Interaction, Init
- Centralized `state` object replaces scattered variables
- 16 DOM refs cached at IIFE scope

### Added

- Behavioral test suite (`demo/test.html`) with 40 tests
- Skip-if-unchanged: polls don't trigger re-render when data hasn't changed
- No-results state: distinct from empty state when search/filter matches nothing
- Dynamic page title: `Claude Activity (N today)`
- Version number shown in meta area
- `prefers-color-scheme`: defaults to light theme on light-preferring systems
- Accessibility: `aria-label`, `aria-live`, `aria-expanded`, `:focus-visible`
- Reload error handling: `onerror` on script tag, clipboard `.catch()` fallback

### Removed

- `esc()` function (no longer needed — `el()` is XSS-safe by construction)
- All `innerHTML` rendering of user data

## [0.7.0] - 2026-03-25

### Added

- `/claude-activity:dashboard` skill for opening dashboard in browser
- `SessionStart` hook with "Activity dashboard available" message
- In-progress staleness heuristic: entries older than 10 minutes show orange dot and "Status unknown"
- Improved empty state with explanation and skill hint

### Fixed

- Peek popover closes on hide/restore project actions
- Peek scroll dismiss only triggers on page scroll, not popover-internal scroll
- Peek popover clamped to viewport top when it can't fit above or below
- Light theme `--text-muted`/`--text-dim` values corrected

## [0.6.0] - 2026-03-25

### Added

- Peek popover: click any entry to see full prompt, response, effort, and duration
- In-progress visual state: pulsing green dot and "now" label for entries with null response
- Duration badge on timeline entry hover
- Hero line skips in-progress entries, shows last completed

### Changed

- Toast z-index bumped above theme-menu

### Removed

- Expandable-prompt click behavior (replaced by peek popover)

## [0.5.0] - 2026-03-25

### Added

- Stop hook (`on-stop.sh`): enriches entries with response text, effort count, and duration
- New data fields: `response`, `effort_total`, `duration_s`, `slug`, `branch`, `session_file`
- Shared library (`lib-activity.sh`) with portable mkdir-based locking
- `.jq` filter files for isolated session JSONL parsing
- One-time migration from v0.4 `activity.jsonl` to new data shape

### Changed

- `log-prompt.sh` renamed to `on-prompt.sh`, writes directly to `activity.js`
- Entries created with `response: null` (filled by Stop hook)

### Removed

- `generate-dashboard.sh` (logic absorbed into `lib-activity.sh`)
- `activity.jsonl` intermediate file (migrated to `activity.js`)
- `transcript` field (replaced by `session_file`)

## [0.4.0] - 2026-03-23

### Added

- Session-color indicators: each session gets a unique color from a dedicated palette
- Colored left-border stripe and timeline dots per session
- Hover-highlight effect: hovering an entry highlights all entries of the same session and dims the rest

## [0.3.1] - 2026-03-23

### Fixed

- Filter pills sticky bar z-index so it stays above timeline entries when scrolling

## [0.3.0] - 2026-03-23

### Added

- Hide/restore projects: dismiss button (×) on Last Touched entries hides a project from Last Touched, filter pills, and timeline
- Restore dialog to bring back hidden projects ("N hidden" link in Last Touched header)
- Expandable prompts in Last Touched (click to expand long prompts)

### Fixed

- Expanded prompts in timeline no longer collapse on auto-refresh

## [0.2.0] - 2026-03-22

### Added

- Theme switcher with 5 themes: Tokyo Night, Catppuccin Mocha, Kanagawa, Catppuccin Latte, Rose Pine Dawn
- Hover effects on view toggle buttons

### Fixed

- Theme picker z-index stacking issues
- Plugin environment variables now correctly passed to background scripts

## [0.1.0] - 2026-03-22

### Added

- `UserPromptSubmit` hook that logs prompts to `activity.jsonl`
- Dashboard HTML with Tokyo Night theme
- Last Touched section showing one entry per project with relative time
- Timeline view grouped by day with expandable long prompts
- Today / 7 Days view toggle
- Project filter pills with counts
- Prompt search
- Keyboard shortcuts (j/k, /, Esc, t/w, r, 0-9, ?)
- Action verb highlighting (fix=red, add=green, research=blue, refactor=yellow)
- Context-aware greeting with clock
- Resume button (copies `claude --resume` command to clipboard)
- Noise filtering: skips short prompts (< 3 words) and bare slash commands
- Auto-refresh every 10 seconds
- Race-condition protection via flock
