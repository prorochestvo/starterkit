---
name: cli-github
description: Access GitHub with gh and apply authorization, issue, pull request, and Projects v2 delivery rules.
---

# GitHub CLI

Prefer `gh` and `gh api`. Verify account and repository context as needed. Technical access does not imply permission to act; global `AGENTS.md` restrictions take precedence.

| Reference | Load when |
|---|---|
| `references/authentication.md` | Connecting, checking identity, or accessing GitHub |
| `references/permissions.md` | Performing writes, publishing, merging, or other sensitive operations |
| `references/issues.md` | Delivering work tracked as GitHub issues |
| `references/projects.md` | Working with the defined Projects v2 board |
| `references/pull-requests.md` | Creating, updating, reviewing, or handing off PRs |

If the `github-account` skill is available, use it for the issue delivery workflow (`references/issues.md`, `references/projects.md`) and before any `gh` write to a repository it gates.
