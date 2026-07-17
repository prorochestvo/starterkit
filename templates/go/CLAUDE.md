# CLAUDE.md

This file provides guidance to Claude Code when working with code in this repository.

> **Template note.** Replace every `<...>` placeholder with real project values, then
> delete this note. Conventions (style, test structure, error contract, code
> organization) come from the `stack-go` plugin skills — this file holds only what is
> specific to THIS project.

## What this service is

<One paragraph: what the service does and its main flow.>

## Build & run

```bash
make build    # builds binaries to ./build/
make run      # runs the application
make test     # go fmt + go vet + go test -race ./...
make lint     # go vet + forbidden-import checks
```

Targeted runs: standard `go test` flags (`-run`, `-bench=. -benchmem -run=^$`,
`-race`), prefixed with `CGO_ENABLED=0`, scoped to `./<package>/`.

## Architecture

| Layer | Location | Role |
|-------|----------|------|
| Entry point | `cmd/<binary>/` | Composition root, startup wiring (inlined per binary) |
| Service | `internal/service/` | Business logic |
| Domain | `internal/domain/` | Domain types and invariants |
| Gateway | `internal/gateway/` | Routers, controllers, middleware |
| Repository | `internal/repository/` | Persistence queries |
| Infrastructure | `internal/infrastructure/` | External clients (DB, third-party APIs) |

<Adjust rows to the real layout. Delete what doesn't exist.>

## Database

- Engine: `<engine + driver>` (pure-Go driver, `CGO_ENABLED=0`).
- Migrations: `<./migrations/*.sql>` via `//go:embed`; `cmd/migrator` is the only
  thing that mutates schema; services verify schema currency at startup and fail fast.
- Deploy order: `make build` → `make migrate` → `make run`.

## HTTP routes

- `GET /api/<resource>` — <what it returns>
- `GET /ping` — liveness (no dependencies, always 200)
- `GET /health/check` — readiness (real per-dependency probes)

## Environment variables

- `<NAME>_DSN` — <purpose>. Format: `<scheme://...>`

Never read or edit `.env` files.

## Key dependencies

- `<module path>` — <purpose>
- Go version: `<x.y.z>`

## Deployment

<systemd unit / Docker / k8s — how this ships.>

## Working agreement

All non-trivial work follows the plan-first pipeline:

1. **Plan** — the `architect` agent writes `plans/NNN-slug.md` (create via the
   `pipeline:new-plan` skill). No source edits before a plan exists.
2. **Implement** — the `engineer` agent executes the plan's tasks with tests.
3. **Review** — three `reviewer` agents launched in parallel in ONE message, each
   prompt naming its lens (A: correctness & tests, B: security & operations,
   C: performance & architecture) and the changed files. Full three-lens fan-out is
   mandatory on the first review; the post-fix re-review is ONE solo reviewer scoped
   to the changed lines.
4. **Gate** — `make test` must be green before review; a red tree goes to the
   `testdoctor` agent first, at any stage.
5. **Complete** — the orchestrator merges the three reports, deduplicates, resolves
   conflicting verdicts (naming what was rejected and why; the user has final say).
   P0/P1 findings loop back to the engineer. Only when every P0/P1 is fixed or
   explicitly accepted: move the plan via the `pipeline:complete-plan` skill.

Plans live in `plans/` (active), `plans/completed/` (shipped, `YYMMDD.NNNN.slug.md`),
`plans/history/` (abandoned/superseded). One plan per concern.
