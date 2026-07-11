# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- `install.sh --daemon` installs cryo as a launchd service (macOS) with auto-restart on crash/login
- `install.sh --uninstall-daemon` stops and removes the launchd service
- `KILL_LIST` extended with `AddressBookSourceSync`, `contactsdonationagent`

### Fixed
- `install.sh` now falls back to `~/.local/bin` without requiring sudo when `/usr/local/bin` is not writable
- Removed orphan `cryo.bats` (superseded by `test_cryo.sh`)
- Fixed `actions/checkout@v5` reference in CI (v5 does not exist — corrected to v4)

### Changed
- CONTRIBUTING.md updated to reflect standalone test suite (bats no longer required)
- README.md: added macOS bash 4+ note to Development section

## [1.0.0] - 2025-01-01

### Added
- Initial public release
- CPU and memory throttling via `renice`
- Worker cleanup for eslint, puppeteer, vitest, Claude snapshot processes
- Dry-run mode
- Standalone test suite (`test_cryo.sh`, 27 tests, no external dependencies)
- `install.sh` one-liner installer
