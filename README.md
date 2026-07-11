# cryo

Automatically throttle runaway CPU and memory hogs on macOS and Linux.

[![CI](https://github.com/nadimtuhin/cryo/actions/workflows/ci.yml/badge.svg)](https://github.com/nadimtuhin/cryo/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Security Policy](https://img.shields.io/badge/security-policy-blue.svg)](SECURITY.md)

Leave cryo running in the background. If a process starts eating too much CPU or RAM, cryo drops its priority so your machine stays responsive. It also cleans up abandoned dev tools that hang around in the background.

## Features

- **CPU throttling** — processes using over 5% CPU go to nice +10. Anything over 50% drops to nice +19.
- **Memory throttling** — same logic for processes consuming excessive RAM.
- **Worker cleanup** — hunts down and kills orphaned eslint, puppeteer, vitest, or Claude snapshot processes.
- **Dry run** — see what cryo would prioritize or terminate before making changes.
- **Dashboard** — minimal terminal view of active throttles and cleanup stats.

## Quick start

```bash
# Preview what would be reniced
cryo --once --dry-run

# Run in the foreground
cryo

# Run as a background daemon (manual)
nohup cryo > /tmp/cryo.log 2>&1 &
```

## Install

```bash
curl -fsSL https://raw.githubusercontent.com/nadimtuhin/cryo/main/install.sh | bash
```

Requires Bash 4+. If you are on default macOS Bash (version 3), upgrade via Homebrew:

```bash
brew install bash
```

### Run as a launchd service (macOS)

Auto-starts at login and restarts if killed — no need to babysit a background process:

```bash
./install.sh --daemon             # install + start
./install.sh --uninstall-daemon   # stop + remove
```

Logs to `~/.local/logs/cryo.log`.

## Configuration

| Flag | Default | Description |
|------|---------|-------------|
| `--once` | false | Run one pass and exit |
| `--dry-run` | false | Preview changes without modifying processes |
| `--interval N` | 60 | Seconds between passes |
| `--threshold N` | 5.0 | CPU % threshold to trigger priority drop |
| `--mem-threshold N` | 5.0 | Memory % threshold to trigger priority drop |
| `--top N` | 0 (all) | Limit visualization to the top N resource users |
| `--eslint-max-age N` | 600 | Max lifetime for eslint workers in seconds |
| `--puppeteer-max-age N` | 600 | Max lifetime for puppeteer/chrome workers |
| `--vitest-max-age N` | 300 | Max lifetime for vitest processes |
| `--claude-snapshot-max-age N` | 300 | Max lifetime for shell snapshot processes |
| `--kill` | — | Stop the active daemon |
| `--help` | — | Show usage options |

install.sh flags:

| Flag | Description |
|------|-------------|
| `--daemon` | Install + start cryo as a launchd auto-restart service (macOS) |
| `--uninstall-daemon` | Stop and remove the launchd service |
| `--uninstall` | Remove the cryo binary |

## Example output

```
cryo  14:23:05  ⟳ 60s  cpu≥5.0%  mem≥5.0%
──────────────────────────────────────────────────
  PROCESS (PID)                  CPU%    MEM%  NICE
──────────────────────────────────────────────────
  ● eslint (84211)                67.3%    2.1%  +19
  └                                                     67.3%    2.1%  +19
  ▲ node (83302)                  12.8%    3.4%  +10
  └                                                     12.8%    3.4%  +10
  ○ chromium (84901)               0.0%    6.2%  +10
  └                                                      0.0%    6.2%  +10
──────────────────────────────────────────────────
  3 processes throttled
  ✖ killed 2 stale/orphan eslint worker(s)
```

Indicators:
- **● (red)** — high CPU usage (50%+)
- **▲ (yellow)** — moderate CPU usage (threshold to 50%)
- **○ (cyan)** — high memory usage

## Mechanics

On every interval, cryo:
1. Gathers processes owned by the current user.
2. Skips system processes (like WindowServer or launchd) and itself.
3. Automatically applies lower execution priorities to processes exceeding threshold values.
4. Searches for orphaned dev workers and runs a cleanup cycle.

Throttling is one-way: cryo can lower a process's priority but cannot raise it back without root, so a throttled process stays niced until it exits.

## Why use this?

You don't always know when a build task or test runner will spin out of control. Instead of manually chasing down PIDs or running every task under `nice`, cryo watches your system and handles the spikes for you.

## Development

Standalone test suite, no dependencies:

```bash
bash test_cryo.sh
```

On macOS the system bash is 3.2 — cryo requires bash 4+. Install via Homebrew
and put it on PATH before running tests:

```bash
brew install bash
export PATH="/opt/homebrew/bin:$PATH"
bash test_cryo.sh
```

## License

MIT
