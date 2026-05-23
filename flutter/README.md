# Claude Code Flutter Starter

A project-agnostic starter for Flutter apps that work with Claude Code out of the
box. Drop the template into a fresh Flutter project, fill in the `<...>` placeholders
in `CLAUDE.md`, and you get:

- A `CLAUDE.md` documenting architecture, error handling, planning workflow, agent
  pipeline, and the Flutter-specific **Test Structure** rule built around
  `group()` + `test()` / `testWidgets()` / `blocTest()`.
- Four ready-to-use subagents in `.claude/agents/`:
  - `flutter-architect` — planning and decomposition
  - `flutter-engineer` — implementation
  - `flutter-reviewer` — review and verdicts
  - `flutter-testdoctor` — failing-test triage
- A `.claude/settings.json` with a sensible default permission allowlist for Flutter
  (`flutter test`, `flutter analyze`, `dart format`, common git, etc.) and a strict
  deny list (`.env`, `.idea`, destructive ops).
- Two slash commands in `.claude/commands/`:
  - `/new-plan <slug>` — scaffolds `plans/NNN-slug.md` from the documented template
  - `/complete-plan <NNN|slug>` — moves a plan to `plans/completed/YYMMDD.NNNN.slug.md`
    after `flutter analyze` + `flutter test` pass
- Per-agent memory directories in `.claude/agent-memory/<agent-name>/` with a README
  explaining the commit policy.
- A `plans/` directory with the lifecycle (`active` → `completed/` → `history/`)
  wired in, plus one worked example plan under `plans/completed/`.

## Install

From the starter repo root:

```bash
./install.sh flutter /path/to/your-project
```

This copies `CLAUDE.md`, the entire `.claude/` directory, and the `plans/` skeleton
into the target project. The script refuses to overwrite an existing `CLAUDE.md` or
`.claude/` unless you pass `--force`.

Manual install (if you prefer):

```bash
cp flutter/CLAUDE.md /path/to/your-project/CLAUDE.md
cp -R flutter/.claude /path/to/your-project/.claude
mkdir -p /path/to/your-project/plans/{completed,history}
```

After install, open `CLAUDE.md` and replace every `<...>` placeholder with the real
values for your project (Flutter version, state management library, routing,
networking, persistence, env / config, dependencies, constraints).

## Key Flutter-specific differences from the Go starter

- **`group()` is the subtest equivalent.** Flutter / Dart's `package:test` (re-exported
  by `flutter_test`) provides `group()` for nesting and `test()` / `testWidgets()` /
  `blocTest()` for individual scenarios. The "one container per tested unit" rule is
  expressed as one `group(...)` per tested unit. See **Test Structure** in `CLAUDE.md`.
- **Multiple test types.** Unit, widget, golden, BLoC, and integration tests each
  have specific tools and pitfalls — the test doctor agent has explicit checklists
  for each.
- **State management is a project-wide commitment.** `CLAUDE.md` requires picking one
  (BLoC / Riverpod / Provider / etc.) and the agents enforce that choice.
- **Mocking convention.** `mocktail` is preferred over `mockito` (no codegen, null
  safe). `bloc_test` is the standard for BLoC/Cubit emit-sequence verification.
- **Forbidden constructs differ from Go.** No `print` in production, no `dynamic`
  outside decoding boundaries, no `BuildContext` across `await` without `mounted`,
  no `setState` after `dispose`, no `!` (null-bang) on values whose nullability
  isn't proven.
- **Performance & rebuild scoping.** The reviewer flags `_buildSomething()` helper
  methods (which break `const` and rebuild scoping), missing `const` constructors,
  and `ListView(children: [...])` for long lists.

## Agent memory

Agents write persistent memory to `.claude/agent-memory/<agent-name>/`. These files
are project-scoped and intended to be committed — they capture user preferences,
non-obvious feedback, ongoing project state, and pointers to external resources.
The directories ship with `.gitkeep` placeholders; nothing needs to be created up
front.

## Local overrides

Personal permission overrides go in `.claude/settings.local.json` (committed-ignored
by the starter's `.gitignore`). The committed `.claude/settings.json` is the team
default — keep it conservative and use the local file for per-developer tweaks.
