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
| `pipeline` | Four stack-agnostic agents — `architect` (planning), `engineer` (implementation), `reviewer` (3-lens parallel fan-out), `testdoctor` (red-test triage) — plus skills: `new-plan` / `complete-plan` (plan lifecycle), `sync-permissions` (merges the canonical permission lists into a project's settings; the fragments in its skill directory are the single source of truth for install.sh too), and `onboard` (the install/migration checklist — verifies wiring, permissions, legacy agents, CLAUDE.md shape, plans, memory) |
| `stack-go` | Go conventions (style, declaration order, code organization, error contract, test structure) and Go knowledge: `mistakes` (*100 Go Mistakes*), `concurrency` (*Effective Concurrency in Go*), `performance` (*Efficient Go*) |
| `stack-flutter` | Flutter/Dart conventions: forbidden constructs, state-management discipline, test structure, error contract |
| `knowledge` | Cross-stack doctrine distilled from books: `ddd-strategic`, `ddd-tactical`, `sql-antipatterns`, `postgres-performance`, `mongodb-modeling`, `testing-doctrine`, `production-stability`, `data-systems`, `software-design`, `forecasting` |

Agents carry only their role doctrine; stack conventions and book knowledge live in
skills that load on demand (path-scoped or description-matched), so they cost no
context until they are relevant.

## New project

```bash
./install.sh <go|flutter> /path/to/your-project
```

This copies two files and creates one directory — everything else arrives via plugins:

- `CLAUDE.md` — a thin template holding only project facts (what it is, layers,
  routes, env vars, deps) and the pipeline working agreement. Fill in the `<...>`
  placeholders.
- `.claude/settings.json` — permission allowlist for the stack plus the marketplace
  wiring (`extraKnownMarketplaces` + `enabledPlugins`).
- `plans/` — the plan lifecycle skeleton (`active` → `completed/` → `history/`).

Then start `claude` in the project, approve the marketplace/plugin installation
when prompted (or run `/plugin marketplace add prorochestvo/starterkit` and
`/plugin install <name>@starterkit` manually), and run **`/pipeline:onboard`** — it
walks the full checklist: wiring, permissions, CLAUDE.md placeholders, plans layout,
hygiene.

The script refuses to overwrite existing files unless you pass `--force`.

**Migrating an existing project** (one that predates the marketplace or already has
a `CLAUDE.md`): skip install.sh and run `/pipeline:onboard` directly — it detects
legacy agent clones, superseded commands, convention duplication in CLAUDE.md, and
stale agent memory, fixes the mechanical parts, and hands you a punch list for the
judgment calls.

## The pipeline

```
plan (architect) → implement (engineer) → review (reviewer ×3, parallel lenses:
A correctness & tests · B security & ops · C performance & architecture)
→ fix loop (engineer / testdoctor) → solo re-review of changed lines → complete-plan
```

Gates: the project's test/lint commands (from its `CLAUDE.md`) must be green before
review and before a plan moves to `completed/`. Reviewers grade P0–P3; every P0/P1
is fixed or explicitly accepted before completion.

## Books

`books/` holds the source PDFs the knowledge skills were distilled from. It is
gitignored — the PDFs are local raw material, only the distillations are committed.
A skill's header names its source book; regenerating or deepening a skill means
re-reading the relevant chapters and updating the SKILL.md, not committing the book.

## Adding a stack

Create `plugins/stack-<name>/` with a `.claude-plugin/plugin.json` and a
`skills/conventions/SKILL.md` (path-scoped to the stack's file extensions), add the
plugin to `.claude-plugin/marketplace.json`, and add a `templates/<name>/` pair
(`CLAUDE.md` + `settings.json`). The pipeline agents pick up the stack via its
conventions skill — no agent changes needed.

## License

[MIT](./LICENSE)
