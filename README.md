# Claude Code Starters

Project-agnostic starter kits for working with [Claude Code](https://claude.ai/code)
across three stacks. Each subdirectory drops into a fresh (or existing) project and
gives you a ready-to-use `CLAUDE.md`, a four-agent pipeline, and a planning workflow.

## Stacks

| Directory | Stack | Agents |
|-----------|-------|--------|
| [`flutter/`](./flutter) | Flutter / Dart | architect · engineer · reviewer · testdoctor |
| [`golang/`](./golang) | Go | architect · engineer · reviewer · testdoctor |
| [`scala/`](./scala) | Scala | architect · engineer · reviewer · testdoctor |

Each starter is independent — pick the one matching your stack and ignore the rest.

## What you get

- **`CLAUDE.md`** — architecture, error-handling contract, test structure rule,
  planning workflow, and the agent pipeline, with `<...>` placeholders to fill in
  for your project.
- **Four specialized agents** in `.claude/agents/`:
  - `*-architect` — planning and decomposition
  - `*-engineer` — implementation
  - `*-reviewer` — review and verdicts
  - `*-testdoctor` — failing-test triage
- **`plans/` directory** — lifecycle wired in (`active` → `completed/` → `history/`).

## How to use

1. Copy the contents of the relevant stack directory into your project:
   ```
   CLAUDE.md
   .claude/agents/*.md
   plans/
   ```
2. Open `CLAUDE.md` and replace every `<...>` placeholder with the real values
   for your project (versions, libraries, dependencies, constraints).
3. Optionally adjust the agents in `.claude/agents/` — most project-specific edits
   should land in `CLAUDE.md` rather than in the agents themselves.
4. Start a session with Claude Code in the repo. The agents and planning workflow
   are picked up automatically.

See the per-stack READMEs for stack-specific notes (e.g. [`flutter/README.md`](./flutter/README.md)).

## Agent memory

Agents write persistent memory to `.claude/agent-memory/<agent-name>/`. These files
are project-scoped and intended to be committed — they capture user preferences,
non-obvious feedback, ongoing project state, and pointers to external resources.

## License

[MIT](./LICENSE)
