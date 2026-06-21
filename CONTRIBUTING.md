# Contributing to cryo

Thanks for your interest in contributing!

## Getting Started

1. Fork and clone the repo
2. Make your changes in a feature branch: `git checkout -b my-feature`
3. Test your changes (see Testing below)
4. Submit a pull request against `main`

## Development

cryo is a single bash script (`cryo`). Keep it self-contained — no external
dependencies beyond standard POSIX/bash utilities.

## Testing

Tests use [bats-core](https://github.com/bats-core/bats-core).

Install bats:

    brew install bats-core        # macOS
    sudo apt install bats         # Debian/Ubuntu

Run the test suite:

    bats cryo.bats

All tests must pass before a PR can be merged.

## Code Style

- Use 2-space indentation
- Quote all variables: `"$var"` not `$var`
- Add a comment for any non-obvious logic
- Keep functions small and focused

## Submitting a Pull Request

- Describe what the PR does and why
- Reference any related issues: `Fixes #123`
- Keep PRs focused — one change per PR
- Ensure CI passes

## Reporting Bugs / Requesting Features

Use the GitHub issue templates:
- Bug reports: describe steps to reproduce and expected vs actual behavior
- Feature requests: describe the problem and proposed solution

## License

By contributing you agree your work is released under the same license as
this project.
