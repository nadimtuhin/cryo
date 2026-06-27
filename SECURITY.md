# Security Policy

## Reporting a vulnerability

Please **do not** open a public GitHub issue for security vulnerabilities.

Use [GitHub Security Advisories](https://github.com/nadimtuhin/cryo/security/advisories/new) for private disclosure.

Expected response time: within 7 days.

## Supported versions

Only the latest release on the `main` branch receives fixes.

## Scope

cryo reads process information via `ps` and applies `renice`. It does not make network requests, read user files, or store data. Reports about privilege escalation or unintended process termination are in scope.
