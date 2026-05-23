# Claude Code Starters

Project-agnostic starter kits for working with [Claude Code](https://claude.ai/code)
across three stacks. Each subdirectory drops into a fresh (or existing) project and
gives you a ready-to-use `CLAUDE.md`, a four-agent pipeline, default permissions,
slash commands, and a planning workflow.

## Stacks

| Directory | Stack | Reviewer pipeline |
|-----------|-------|-------------------|
| [`flutter/`](./flutter) | Flutter / Dart | single reviewer |
| [`golang/`](./golang) | Go | 5-reviewer fan-out |
| [`scala/`](./scala) | Scala (ZIO) | single reviewer |

Each starter is independent — pick the one matching your stack and ignore the rest.

## What you get per stack

- **`CLAUDE.md`** — architecture, error-handling contract, test structure rule,
  planning workflow, and the agent pipeline, with `<...>` placeholders to fill in
  for your project.
- **Four subagents** in `.claude/agents/`:
  - `*-architect` — planning and decomposition
  - `*-engineer` — implementation
  - `*-reviewer` — review and verdicts
  - `*-testdoctor` — failing-test triage
- **`.claude/settings.json`** — committed default permission allowlist tuned to the
  stack (build/test/lint commands, common git), and a strict deny list (`.env`,
  `.idea`, destructive ops). Personal overrides go in `.claude/settings.local.json`
  (gitignored).
- **`.claude/commands/`** — two slash commands:
  - `/new-plan <slug>` scaffolds the next `plans/NNN-slug.md`
  - `/complete-plan <NNN|slug>` verifies the stack's test/lint gates and moves the
    plan to `plans/completed/YYMMDD.NNNN.slug.md`
- **`.claude/agent-memory/<agent-name>/`** — empty per-agent memory directories
  with a README explaining the commit policy.
- **`plans/`** — lifecycle (`active` → `completed/` → `history/`) wired in, with
  one worked example plan per stack under `plans/completed/`.

## Install

From this repo's root:

```bash
./install.sh <flutter|golang|scala> /path/to/your-project
```

The script copies `CLAUDE.md`, the entire `.claude/` directory, and the `plans/`
skeleton into the target project. It refuses to overwrite existing files unless you
pass `--force`.

After install, open `CLAUDE.md` in the target project and replace every `<...>`
placeholder with real values (versions, libraries, dependencies, constraints).
Review `.claude/settings.json` and tighten or loosen the allowlist for your context.

See the per-stack READMEs for stack-specific notes:
[flutter](./flutter/README.md) · [golang](./golang/README.md) · [scala](./scala/README.md).

## Why ship `.claude/` instead of telling people to write their own?

- **Zero permission prompts on day one** for the obvious safe commands of each stack.
- **Slash commands automate the brittle parts** of the planning workflow (the
  `YYMMDD.NNNN` rename in particular is easy to get wrong by hand).
- **Agent memory** survives across sessions, so feedback the user gives ("don't mock
  the database", "stop summarizing at the end") sticks.

## License

[MIT](./LICENSE)
