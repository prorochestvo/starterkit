---
name: cli-git
description: Rules for Git commits, branches, push, and history operations.
---

# Git CLI

Use this skill for Git operations. Read only the references needed by the operation; multiple references may apply.

| Reference | Load when |
|---|---|
| `references/commits.md` | Creating, amending, or reviewing commits |
| `references/branches.md` | Creating, naming, switching, or deleting branches, landing a branch as a squash commit, rebasing branches after one, removing worktrees, promoting `dev` into `main`, or checking commit permissions |
| `references/push.md` | Pushing or rewriting remote history; creating, moving, deleting, or pushing a tag |

Global approvals in `AGENTS.md` remain binding even if a reference is not loaded. Follow repository-enforced conventions where applicable.
