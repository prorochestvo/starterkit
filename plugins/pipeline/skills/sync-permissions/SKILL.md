---
name: sync-permissions
description: Merge the starterkit's canonical permission allow/deny lists into this project's .claude/settings.json. Use after updating the starterkit, when wiring an existing project into the marketplace, or to audit local permission drift.
---

Bring this project's `.claude/settings.json` permissions up to date with the
starterkit canon. The canonical fragments live next to this skill file
(`${CLAUDE_PLUGIN_ROOT}/skills/sync-permissions/` when installed as a plugin):

- `core.json` — stack-agnostic allow (coreutils, git) and deny (`.env`, `.idea`, destructive git/rm).
- `stack-go.json` / `stack-flutter.json` — per-stack toolchain allowlists and denies.

Steps:

1. Read the project's `.claude/settings.json`. If missing, stop and tell the user to
   scaffold first (install.sh) — this skill syncs, it does not bootstrap.
2. Determine active stacks from `enabledPlugins` (`stack-go@...`, `stack-flutter@...`).
3. Read `core.json` plus the fragment for each active stack.
4. **Additive merge, never destructive**: union the fragments' `allow` and `deny` into
   the existing arrays. Preserve every existing entry; never remove or rewrite one;
   never touch other keys (`extraKnownMarketplaces`, `enabledPlugins`, hooks, etc.).
   Keep 2-space JSON indentation. Skip exact duplicates.
5. Report three lists:
   - **Added** — canonical entries that were missing and are now merged.
   - **Local extras** — entries present in the project but not in canon. Take no
     action; flag ones that look like promotion candidates (broadly useful, safe) vs
     one-off approvals that could be pruned by hand.
   - **Local-settings overlap** — if `.claude/settings.local.json` exists, entries in
     it that canon now covers (safe to prune from the local file by hand).
6. Validate the result parses (`python3 -m json.tool`) before finishing.

Do not edit `.claude/settings.local.json` — it is personal scope; only report on it.
