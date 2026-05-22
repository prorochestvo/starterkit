# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

> **Template note.** This is a project-agnostic Go starter. Replace the `<...>`
> placeholders and the example sections below with the real values for your project.
> Anything inside a `<...>` is a marker that must be filled in or removed before the
> file is considered complete.

## Build & Run Commands

All commands assume a pure-Go build with `CGO_ENABLED=0` (recommended default). Adjust
if your project legitimately needs CGO.

```bash
make build    # Builds binaries to ./build/
make run      # Runs the application (migrations + service start, if applicable)
make test     # go fmt + go vet + go test -race ./...
make lint     # go vet + checks for forbidden imports
make format   # go fmt ./...
make clean    # Removes binaries + go mod tidy
```

Targeted test runs:
```bash
# Single top-level test
CGO_ENABLED=0 go test -race -run TestFunctionName ./<package>/

# Single subtest
CGO_ENABLED=0 go test -race -run 'TestFunctionName/subtest_name' ./<package>/

# Verbose output (see every subtest pass/fail)
CGO_ENABLED=0 go test -race -v ./<package>/

# Benchmarks
CGO_ENABLED=0 go test -bench=. -benchmem -run=^$ ./<package>/

# Coverage
CGO_ENABLED=0 go test -race -coverprofile=cover.out ./... && go tool cover -html=cover.out
```

## Architecture Overview

<One-paragraph description of what this service does and its main flow.>

### Layer Responsibilities

Replace the rows below with the real layout of your project. The example below uses a
common layered Go layout — keep, edit, or remove rows as needed.

| Layer | Location | Role |
|-------|----------|------|
| Entry point | `cmd/<binary>/` | Composition root, server bootstrap |
| Bootstrap | `internal/bootstrap/` | Shared startup wiring (logger, DB gate, repository bundle) — used only by `cmd/*` |
| Application | `internal/application/service/` | Business logic orchestration |
| Domain | `internal/domain/` | Value objects / models, no logic |
| Gateway | `internal/gateway/` | Routers, controllers, middleware |
| Repository | `internal/repository/` | Persistence queries |
| Infrastructure | `internal/infrastructure/` | External clients (DB, third-party APIs) |
| Tools | `internal/tools/` | Cross-cutting utilities |

### Key Patterns

Document the patterns that actually shape this codebase. The bullets below are common
defaults — keep what applies, replace the specifics with your own.

- **Repository pattern** — each repository type owns its own SQL and query helpers.
  Queries execute inside explicit transactions; repositories are passed as interfaces
  into the service and handler layers so they can be substituted in tests.
- **Configuration injection** — config is read once at startup in the composition root
  (`cmd/<binary>/main.go`) and passed down as typed values; nothing reads the
  environment ad hoc deeper in the call graph. Required values are validated at startup
  and the binary fails fast (`log.Fatalf`) on any missing one. Secrets come from the
  process environment / a deploy-time `EnvironmentFile`, never from a checked-in file.
  <List the required config keys and their formats here.>
- **Embedded assets** (if any) — describe what is embedded via `//go:embed` and where
  the source files live (e.g. `cmd/<binary>/static/`).
- **Authentication** (if any) — describe the auth scheme for protected endpoints, where
  it is implemented, and how it is made testable (e.g. injecting the validator as a
  function field so tests can substitute a fake without real credentials).

### HTTP Routes

List the public routes and a one-line description of each. Example shape:

- `GET /api/<resource>` — <what it returns>
- `GET /api/<resource>/{id}` — <what it returns>
- `PATCH /api/<resource>/{id}/<field>` — <what it mutates>
- `GET /api/stats` — <global statistics>

> If the project ships operator-only / admin tooling (rule generation, seed auditing,
> one-off probes, etc.), document its umbrella binary and subcommands here, and point
> to that binary's `README.md` / godoc for usage, exit codes, and environment variables.

### Database

Engine: `<engine + driver>` (note CGO status — e.g. a pure-Go driver to keep
`CGO_ENABLED=0`).

Document any connection-level settings applied at open time (pragmas, pool sizes,
timeouts) and the rule of thumb behind them. If foreign keys cascade, call out the
destructive operations explicitly so they are not wired to an endpoint by accident.

**Schema & migrations.** Describe where schema files live and the migration mechanism:

- Migration source: `<./migrations/*.sql>`, exposed to the binary via `//go:embed`
  (e.g. `var MigrationsFS embed.FS` in `migrations/embed.go`) so they ship without
  runtime disk I/O.
- A dedicated migrator (`cmd/migrator`) is the **only** thing that mutates schema. It is
  idempotent: applied filenames are tracked in a `__schema_migrations` table.
- Service binaries DO NOT migrate on startup. They verify the schema is current
  immediately after opening the DB and `log.Fatalf` if it is not (run the migrator
  first).
- Filename convention: `<YYYYMM>.<NNN>.<table>.<description>.sql`, where `<NNN>` is a
  **global** zero-padded counter encoding apply order. Files apply in lexicographic
  order. Once applied to any shared/production DB a filename is **immutable** — renaming
  triggers a duplicate apply. New work uses additive migrations only.
- Reference table/column names through `const` declarations in `internal/repository/`
  so a schema rename surfaces at compile time / via `grep`, never as a runtime
  "no such column" error.

Deploy flow (example):
```
make build         # builds all binaries including ./build/migrator
make migrate       # applies any pending .sql files (no-op if up to date)
make run           # starts the service binaries
```

Document deployment ordering: whether migrations run as a deploy-time step (e.g. CI runs
`cmd/migrator` over SSH against the target before swapping the binary) or some other
way. Prefer schema reconciliation as a deploy-time step, not a startup-time step.

### Environment Variables

List the variables the service reads, their format, and how they are parsed. Example
shape:

- `<NAME>_DSN` — <purpose>. Format: `<scheme://...>`
- ...

> Document any config that is intentionally NOT an env var (e.g. a value passed via a
> CLI flag baked into the deploy unit).

> Never read or edit `.env` files.

### Key Dependencies

List third-party libraries the project depends on and the Go version. Example shape:

- `<module path>` — purpose
- ...
- Go version: `<x.y.z>`

### Frontend (if any)

Describe any embedded or served frontend assets and their location.

### Deployment

Describe how the service is deployed (systemd unit, Docker, k8s, etc.).

## Error Handling

Define the project's error-handling contract here. The example below describes a
common pattern of separating user-facing errors from internal failures — keep, adapt,
or replace it.

### `PublicError` — user-facing errors (example pattern)

A dedicated error type (commonly `internal.PublicError` or similar) is the mechanism for
surfacing safe, human-readable messages to end users. Any error message that is **safe
to show** to a user is wrapped with `internal.NewPublicError(...)` at the point where
the error is created (typically in the service layer).

**Rule**: if a function can fail in a way that meaningfully communicates something to
the user, return a public error. For all other failures (DB down, unexpected nil, etc.)
return a plain error — the controller will send a generic fallback.

#### Creating a public error (service layer)

```go
import "<module>/internal"

// user should know about this
return internal.NewPublicError("Invalid input. <specific guidance>")

// internal failure — user gets generic message
return fmt.Errorf("db query failed: %w", err)
```

#### Error handling in the controller

The controller catches all errors from sub-handlers and sends the appropriate message.

```go
const errFallbackMessage = "Something went wrong. Try again later."
```

| Situation | What service returns | What user sees |
|-----------|---------------------|----------------|
| Expected business failure (validation, state) | `internal.NewPublicError("...")` | The exact message from `PublicError.Details()` |
| Unexpected / infrastructure failure | plain `error` | The fallback message |
| No error | `nil` | Normal happy-path response |

### Testing the error path

Every controller test that exercises an error branch **must** assert:

1. That a response was actually sent (the user is not left in silence).
2. That the sent text equals `PublicError.Details()` when the error is a `PublicError`.
3. That the sent text equals the fallback constant when the error is a plain error.

## Constraints

Replace this section with the real constraints of your project. The list below is a
reasonable default for a CGO-free Go service — keep what applies, drop what doesn't,
add what's missing.

- **Forbidden imports**: list any modules that must never appear in `go.mod` (e.g.
  CGO-dependent drivers, code generators the team has rejected). Enforce via
  `make lint`.
- **Testing**: Use `github.com/stretchr/testify`; run tests with `-race`; parallel
  subtests preferred where there's no shared mutable state.
- **One `Test*` per method, scenarios as subtests**: each tested method/function gets
  exactly one top-level test function named after it (e.g. `TestEncode` for `Encode`),
  and every scenario for that method lives as a `t.Run("descriptive name", ...)`
  subtest inside it. Do **not** create separate top-level tests like
  `TestEncode_EmptyInput`, `TestEncode_Unicode`, `TestEncode_Error` — these belong
  as subtests of a single `TestEncode`. Methods on a type follow the same rule with
  the standard `TestType_Method` form (e.g. `TestUser_Validate`).
  ```go
  func TestEncode(t *testing.T) {
      t.Parallel()

      t.Run("empty input returns empty string", func(t *testing.T) {
          t.Parallel()
          // ...
      })

      t.Run("unicode is preserved", func(t *testing.T) {
          t.Parallel()
          // ...
      })

      t.Run("returns error on invalid byte", func(t *testing.T) {
          t.Parallel()
          // ...
      })
  }
  ```
- **No CGO**: `CGO_ENABLED=0` must be set for all build and test commands (unless the
  project intentionally requires CGO).
- **Compile-time interface checks**: Every mock/stub struct in test files must have a
  `var _ interfaceName = &mockStruct{}` assertion at the top of the file.
- **No section-divider comments**: Do not use `// --- section ---` or `// ----` style
  separator comments. Let the code structure speak for itself.
- **No skipped errors**: Never use `_` to discard error return values in production or
  test code. Always capture the error and assert/check it. The only exceptions are
  `fmt.Fprint*` writes to loggers, `Rollback()` calls in error-recovery paths, and
  resource `.Close()` in `t.Cleanup` / `defer`.
- **Comments**: all comments are in English and start with a lowercase first word
  (e.g. `// wrap the driver error so callers can match on it`).
- **Godoc on exported identifiers**: Every exported identifier (Type, Func, Method,
  Var, Const) gets a doc comment that starts with the identifier name and ends with
  a period — e.g. `// Encode returns the base64-encoded form of v.` Each package
  has exactly one `// Package <name> ...` declaration; `cmd/*` entry points use
  `// Command <name> ...` instead. Skip the comment entirely if it would only
  restate the signature — no `// Foo is a Foo.` fluff. Document concurrency
  guarantees, which methods return `PublicError` vs plain errors, constructor
  lifecycle contracts ("caller must Close"), and error sentinel conditions.
  Preserve existing WHY-comments verbatim; do not overwrite a substantive comment
  with a generic restatement. Unexported symbols only get comments when intent is
  non-obvious — do not bulk-add comments to private helpers.
- **Build outputs live in `./build/`, scratch in `./tmp/`, logs in `./logs/`**:
  Never run `go build` without `-o ./build/<name>` — bare `go build ./cmd/<binary>`
  drops a binary in the project root, which is **not** in `.gitignore` and
  would be picked up by `git add .`. The same applies to any throwaway artifacts,
  fixtures, or intermediate files: use `./tmp/` rather than the repo root. Runtime /
  cyclic logs go to `./logs/`. Only these three directories are gitignored at the root.
- **UI conventions**: Document any project-specific rules about emojis, copy, or
  formatting in user-facing surfaces.

## Planning Workflow

All non-trivial work is tracked as a Markdown plan file before implementation begins.

### Directory layout

```
plans/
├── NNN-task-slug.md     # active / in-progress plans (e.g. 001-fix-auth.md)
├── completed/           # plans for fully shipped tasks (e.g. 260422.0001.fix-auth.md)
└── history/             # archived / cancelled plans
```

### File naming

- **Active plans (`plans/`)** — zero-padded sequential index + kebab-case slug:
  `NNN-description.md` (e.g. `001-fix-unauthorized-middleware.md`, `002-add-rate-limiting.md`).
  Pick the next number by checking the highest existing prefix across `plans/`, `plans/completed/`,
  and `plans/history/`.

- **Completed plans (`plans/completed/`)** — date prefix + zero-padded daily index (4 digits) + slug:
  `YYMMDD.NNNN.description.md` (e.g. `260422.0001.fix-unauthorized-middleware.md`).
  `NNNN` resets to `0001` each day and increments for each additional completion on that day.

- **Archived plans (`plans/history/`)** — keep the original `NNN-` filename from `plans/`.

### Lifecycle

1. **Create** — before touching code, produce a plan file in `plans/` using the `NNN-slug.md`
   naming convention described above.
2. **Implement** — work through the tasks defined in the plan. The plan file stays in
   `plans/` while work is in progress.
3. **Complete** — once every acceptance criterion is met and `make test` passes, rename
   and move the file to `plans/completed/` using the date-based convention:
   ```bash
   mv plans/001-fix-auth.md plans/completed/260422.0001.fix-auth.md
   ```
4. **Archive** — if a plan is abandoned or superseded without being fully implemented or
   if we need to save intermediate data or task execution logs, move it to `plans/history/` instead.

### Plan file format

Every plan file follows this structure:

```markdown
# Task Breakdown

## Overview
## Assumptions
## Tasks
### Task N: <Title>
- Description:
- Acceptance Criteria:
- Pitfalls & edge cases:
- Complexity: Easy / Medium / Hard
## Execution Order
## Risks
## Trade-offs
```

### Rules

- **One plan per concern.** Don't bundle unrelated changes in a single plan file.
- **Plan before code.** Claude must create (or confirm an existing) plan file before
  writing or modifying any source files.
- **Keep plans honest.** If implementation diverges from the plan, update the plan file
  before moving it to `completed/`.
- **Slug matches intent.** The description part of the filename should be readable at a glance:
  `002-add-rate-limiting.md`, `003-migrate-sqlite-to-postgres.md`, not `004-task.md`.

## Agent Pipeline

All non-trivial tasks follow a three-stage pipeline using specialized agents. The review
stage fans out to **five `gocode-reviewer` instances running in parallel**, each
with a distinct lens. A separate `gocode-testdoctor` agent is invoked on-demand
whenever tests fail, at any stage.

```
User describes task
    ↓
1. gocode-architect
    → Creates plan file at plans/NNN-slug.md (see Planning Workflow)
    ↓
2. gocode-engineer
    → Implements the tasks defined in the plan
    ↓
3. gocode-reviewer × 5 (run in parallel — single message, five tool calls)
    Lens A: correctness, races, edge cases, error paths
    Lens B: tests, coverage, flakiness, fixtures
    Lens C: ops, observability, log volume, operator UX
    Lens D: security, input validation, secrets, auth boundaries
    Lens E: performance & architecture — allocations, blocking I/O,
            goroutine/resource leaks, API contracts (breaking changes,
            exported surface stability), interface boundaries, layering
            (dependency direction), future-proofing
    ↓
   Orchestrator synthesises all five reports, deduplicates findings,
   resolves conflicts (e.g. one reviewer flags as Blocker what another
   accepts as a trade-off), and presents the merged punch list to the user.
    ↓
  ❌ Blocker/Major found?  → Back to gocode-engineer with the consolidated findings.
                             After fix, run ONE targeted reviewer pass on the changed
                             lines (not all 5 again) before re-approval.
  ⚠️  Tests failing?        → gocode-testdoctor diagnoses and patches, then rerun the
                             targeted reviewer pass.
  ✅ All five approve?      → Orchestrator moves the plan: mv plans/NNN-slug.md
                             plans/completed/YYMMDD.NNNN.slug.md
```

### Agent responsibilities

| Agent | Owns | Output |
|-------|------|--------|
| `gocode-architect` | Planning, decomposition, trade-offs | New plan file in `plans/` |
| `gocode-engineer` | Implementation, tests for new code | Code + tests in the repo |
| `gocode-reviewer` (×5, parallel) | Lens-specific verdicts, severity-ranked findings, patch sketches | Five independent review reports |
| `gocode-testdoctor` | Triage of failing tests, minimal patches | Code/test fixes, re-run of `make test` |

The orchestrating agent (the main Claude session driving the pipeline) owns
synthesis: merging the five reports, resolving conflicting verdicts, deciding
which findings to act on, and moving the plan to `completed/` once everyone
signs off.

### Rules

- **No skipping stages.** Every task starts with the architect and ends with the five-reviewer fan-out.
- **Plan file first.** The architect MUST produce a plan file before any code is written. If a plan already exists for the task, update it rather than creating a new one.
- **Five reviewers, five lenses, one message.** All five `gocode-reviewer` agents are launched in a single tool-call batch (multiple `Agent` blocks in one message) so they run in parallel. Each prompt names the lens explicitly and tells the agent what to SKIP (the other lenses) to avoid duplicated work.
- **No solo reviewer pass on first review.** Even for small changes the full five-lens fan-out is required, because the lenses catch genuinely different classes of issue (Reviewer A won't see test gaps, Reviewer D won't see log-volume problems). Skipping lenses is what the orchestrator does AFTER a Blocker/Major fix, not BEFORE the first verdict.
- **Lens prompts are self-contained.** Each reviewer's prompt must include: (1) the lens name, (2) what to focus on, (3) what to SKIP (so it doesn't restate other lenses), (4) the file list, (5) the deliverable shape (Blocker / Major / Minor / Nit with file:line + patch sketch), (6) the word cap (typically 600 words).
- **Re-review after fixes is single-pass.** Once an engineer addresses Blocker/Major findings, the orchestrator runs ONE reviewer pass scoped to the changed lines, not the full fan-out. Re-running all five each iteration is expensive and rediscovers nothing.
- **Conflict resolution is explicit.** When reviewers disagree (one says Blocker, another says trade-off), the orchestrator chooses, names the rejected suggestion, and explains the reasoning to the user before moving on. The user has final say.
- **Orchestrator gates completion.** The plan moves to `plans/completed/` only after every reviewer's Blocker and Major findings are addressed (either fixed, or explicitly accepted with rationale). The rename uses the standard `YYMMDD.NNNN.slug.md` format.
- **`make test` must pass** before review begins. If it fails, hand the logs to `gocode-testdoctor` first — reviewers should not waste time on a red tree.
- **Testdoctor is scoped.** It patches tests or the minimal production code needed to make the failure go away. It does not redesign or refactor.
