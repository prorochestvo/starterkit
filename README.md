# Starterkit

A [Claude Code](https://claude.ai/code) plugin marketplace that gives every new
project the same engineering machinery without copy-pasting it: a plan-first agent
pipeline, per-stack conventions, and distilled book knowledge — all delivered as
plugins that update centrally.

## How it works

This repo **is** a plugin marketplace (`.claude-plugin/marketplace.json`). Projects
declare it in `.claude/settings.json` and enable the plugins they need; improving an
agent or a skill here propagates to every project via `/plugin marketplace update
starterkit` instead of re-copying files.

| Plugin | Contents |
|--------|----------|
| `pipeline` | Four stack-agnostic agents — `architect` (planning), `engineer` (implementation), `reviewer` (3-lens parallel fan-out), `testdoctor` (red-test triage) — plus the plan-lifecycle, permission-sync, and onboarding skills |
| `stack-go` | Go conventions (style, declaration order, code organization, error contract, test structure) and Go knowledge distilled from *100 Go Mistakes*, *Effective Concurrency in Go*, and *Efficient Go* |
| `stack-flutter` | Flutter/Dart conventions: forbidden constructs, state-management discipline, test structure, error contract |
| `knowledge` | Cross-stack doctrine: DDD (strategic/tactical), SQL antipatterns, PostgreSQL performance, MongoDB modeling, testing, production stability, data systems, software design, and forecasting |

Agents carry only their role doctrine; stack conventions and book knowledge live in
skills that load on demand (path-scoped or description-matched), so they cost no
context until they are relevant.

## Quick start

```bash
./install.sh <go|flutter> /path/to/your-project
```

This copies two files and creates one directory — everything else arrives via plugins:

- `CLAUDE.md` — a thin template holding only project facts (what it is, layers,
  routes, env vars, deps) and the pipeline working agreement.
- `.claude/settings.json` — the stack's permission allowlist plus the marketplace
  wiring (`extraKnownMarketplaces` + `enabledPlugins`).
- `plans/` — the plan lifecycle skeleton (`active` → `completed/` → `history/`).

Start `claude` in the project, approve the marketplace/plugin install when prompted,
and run **`/pipeline:onboard`** — it walks the full checklist (wiring, permissions,
`CLAUDE.md` placeholders, plans layout, hygiene). The script refuses to overwrite
existing files unless you pass `--force`.

To migrate a project that predates the marketplace, skip `install.sh` and run
**`/pipeline:onboard`** directly — it detects legacy agent clones, superseded
commands, convention duplication, and stale agent memory, then hands you a punch list
for the judgment calls.

## The pipeline

```
plan (architect) → implement (engineer) → review (reviewer ×3, parallel lenses:
A correctness & tests · B security & ops · C performance & architecture)
→ fix loop (engineer / testdoctor) → solo re-review of changed lines → complete-plan
```

The project's test/lint commands (from its `CLAUDE.md`) must be green before review
and before a plan moves to `completed/`. Reviewers grade P0–P3; every P0/P1 is fixed
or explicitly accepted before completion.

## License

[MIT](./LICENSE)
