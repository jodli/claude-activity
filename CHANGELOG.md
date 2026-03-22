# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.1/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
