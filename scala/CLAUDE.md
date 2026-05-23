# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

> **Template note.** This is a project-agnostic Scala (ZIO) starter. Replace the `<...>`
> placeholders and the example sections below with the real values for your project.
> Anything inside a `<...>` is a marker that must be filled in or removed before the
> file is considered complete.

## Build & Run Commands

```bash
sbt compile                       # Compile main sources
sbt Test/compile                  # Compile test sources
sbt run                           # Run the default main class
sbt "runMain <package>.<Main>"    # Run a specific main class
sbt clean                         # Remove build artifacts (target/)
sbt reload                        # Reload build definition after changing build.sbt
sbt assembly                      # Build a fat JAR (if sbt-assembly is enabled)
sbt "Docker/publishLocal"         # Build a Docker image (if sbt-native-packager is enabled)
```

Formatting & linting:
```bash
sbt scalafmtAll                   # Format all sources (main + test + build)
sbt scalafmtCheckAll              # Verify formatting (CI-friendly, non-mutating)
sbt scalafixAll                   # Apply scalafix rules (organize imports, remove unused, etc.)
sbt "scalafixAll --check"         # Verify scalafix rules without rewriting (CI-friendly)
```

Test commands:
```bash
sbt test                                  # Run all tests
sbt "testOnly <package>.<SuiteName>"      # Run a single test suite
sbt "testOnly *<SuiteName>"               # Run a suite by short name
sbt "testOnly *Foo* -- -t \"scenario name\""  # Filter by test/label name
sbt "Test/testQuick"                      # Re-run only failed/affected tests
sbt coverage test coverageReport          # Run with coverage (if sbt-scoverage is enabled)
```

## Architecture Overview

<One-paragraph description of what this service does and its main flow.>

### Scala / Toolchain Versions

- Scala: `<2.13.x | 3.x.y>`
- JDK: `<17 | 21>`
- sbt: `<1.x.y>`
- Effect system: `<ZIO 2.x | Cats Effect 3.x>`

### Layer Responsibilities

Replace the rows below with the real layout of your project. The example below uses a
common ports-and-adapters / clean-architecture layout — keep, edit, or remove rows as
needed.

| Layer | Location | Role |
|-------|----------|------|
| Entry point | `src/main/scala/<pkg>/Main.scala` | Runtime bootstrap, `ZLayer` wiring, app composition |
| Domain | `src/main/scala/<pkg>/domain/` | Pure entities, value objects, domain errors — no effects/IO |
| Application / service | `src/main/scala/<pkg>/service/` | Service traits + impls, business logic, orchestration |
| Infrastructure | `src/main/scala/<pkg>/infra/` | DB, HTTP clients, queues, external API adapters |
| API / transport | `src/main/scala/<pkg>/api/` | HTTP routes/endpoints, codecs, request→domain mapping |
| Shared / core | `src/main/scala/<pkg>/core/` | Shared error types, config, logging, common utilities |

### Service / Module Pattern

Pick one and stick with it. Mixing styles makes layer wiring unpredictable.

- **`<service-pattern (trait + final case class impl + ZLayer) | tagless-final | module pattern>`** — chosen approach
- Convention: a service is a `trait` describing capabilities, a `final case class`
  implementation depending on other services via the constructor, and a companion
  `ZLayer` (`<Name>.live`) that wires the dependencies. Accessor methods (or
  `ZIO.serviceWithZIO`) expose the capability at call sites.

### Dependency Injection / Wiring

- Mechanism: `ZLayer` composition (`>>>`, `++`, `ZLayer.make`)
- Composition root: `<path to Main / Layers object>`
- Rule: only the composition root constructs the full environment; downstream code
  declares its requirements in the `R` channel and never builds layers itself.

### HTTP / Transport

- Server: `<zio-http | tapir + zio-http | http4s>`
- Route definitions: `<path>`
- Authentication: `<scheme>`
- Serialization: `<zio-json | circe>`

### Persistence / Data Access

- Library: `<Quill | doobie | zio-jdbc>`
- Database: `<PostgreSQL | MySQL | ...>`
- Connection pool: `<HikariCP | ...>`
- Migrations: `<Flyway | Liquibase | manual>`
- Rule: repository traits live in the application/infra boundary; SQL/queries never
  leak above the repository.

### Configuration

- Library: `<zio-config | typesafe-config / pureconfig>`
- Source: `<application.conf | environment variables | both>`
- Rule: configuration is loaded once into a typed config case class at the composition
  root and passed via a `ZLayer`. No ad-hoc `sys.env(...)` reads scattered in code.

> Never read or edit `.env` files. Never commit secrets or signed key material.

### Key Dependencies

List third-party libraries that materially shape the codebase. Example shape:

- `<library>` — purpose
- ...

### Linting / Static Analysis

- `scalafmt` config in `.scalafmt.conf` — `sbt scalafmtCheckAll` must pass before a PR.
- `scalafix` rules in `.scalafix.conf` — `sbt "scalafixAll --check"` must pass.
- Compiler flags: `<-Wunused | -Xfatal-warnings | -Werror>` enabled in `build.sbt`.
- A clean build with no warnings is required before a PR is approved.

## Error Handling

Define the project's error-handling contract here. The example below describes the
common ZIO pattern of separating **expected, typed failures** (the `E` channel) from
**unexpected defects** (`die` / `Cause.Die`). Keep, adapt, or replace it.

### Typed domain errors — the `E` channel

Expected, recoverable failures are modeled as a sealed hierarchy and surfaced through
the ZIO error channel (`ZIO[R, DomainError, A]`). Anything that is **not** recoverable
by the caller (programming bugs, broken invariants) becomes a defect via
`ZIO.die`/`orDie` and is handled only at the boundary.

```scala
// core/error/DomainError.scala
sealed trait DomainError extends Product with Serializable {
  def message: String
}

object DomainError {
  final case class InvalidInput(message: String)            extends DomainError
  final case class NotFound(id: String) extends DomainError { val message = s"not found: $id" }
  case object Unauthorized extends DomainError              { val message = "unauthorized" }
}
```

### Returning typed errors from a service

Fail with a domain error; never `throw`. Translate infrastructure exceptions into
domain errors at the repository boundary with `mapError`, or promote unexpected ones
to defects with `refineToOrDie`.

```scala
def getUser(id: String): ZIO[Any, DomainError, User] =
  repo
    .findById(id)
    .mapError(e => DomainError.InvalidInput(e.getMessage)) // expected → typed
    .flatMap {
      case Some(user) => ZIO.succeed(user)
      case None       => ZIO.fail(DomainError.NotFound(id))
    }
```

### Translating errors at the transport boundary

The API layer pattern-matches on `DomainError` and maps each case to a response;
defects are caught once and mapped to a generic 500 with a logged cause.

```scala
val ErrFallbackMessage = "Something went wrong. Try again later."

def toResponse(e: DomainError): Response = e match {
  case DomainError.InvalidInput(m) => Response.text(m).status(Status.BadRequest)
  case DomainError.NotFound(_)     => Response.status(Status.NotFound)
  case DomainError.Unauthorized    => Response.status(Status.Unauthorized)
}
```

### Testing the error path

Every test that exercises an error branch **must** assert:

1. The effect fails through the `E` channel (`assertZIO(effect.exit)(fails(...))`), not
   that it dies — unless dying is the intended behavior under test.
2. The failure value equals the expected `DomainError` case.
3. The boundary maps an unexpected defect to the fallback response/cause.

## Constraints

Replace this section with the real constraints of your project. The list below is a
reasonable default for a modern ZIO service — keep what applies, drop what doesn't, add
what's missing.

- **Forbidden constructs**:
  - No `throw` in effectful code — fail through the ZIO error channel
    (`ZIO.fail` / `mapError`).
  - No `Unsafe.unsafe { ... run ... }` / `Runtime.default.unsafe.run` outside the
    composition root or test scaffolding.
  - No `null`; use `Option`. No `.get` on `Option`/`Either`/`Try` — pattern-match or
    fold.
  - No `var` outside tight, justified local scopes; prefer immutable values and `Ref`
    for shared mutable state.
  - No `Await.result` / blocking on a `Future`; wrap blocking calls in
    `ZIO.attemptBlocking`.
  - No non-exhaustive pattern matches (keep `-Wunused`/exhaustivity warnings as errors).
- **Effects only on the boundary**: domain code is pure; effects (`ZIO`) live in the
  service/infra layers. Domain functions return plain values or `Either`, not `ZIO`.
- **Layer discipline**: services declare requirements via the `R` channel; only the
  composition root builds `ZLayer`s.
- **Mocking**: prefer `zio-mock` (`@mockable`) or hand-written test `ZLayer`s over
  reflective mocking frameworks.
- **No silently swallowed errors**: never `.catchAll(_ => ZIO.unit)` or
  `.ignore`/`.orElse(ZIO.unit)` without a logged cause or a comment explaining why the
  swallow is correct.
- **Comments**: all comments are in English and start with a lowercase first word
  (e.g. `// wrap blocking JDBC call to keep the fiber non-blocking`).

## Test Structure

This project uses `<zio-test | MUnit | ScalaTest>`. With **zio-test** the unit of
grouping is `suite(...)`, and the rule mirrors Go's `t.Run` subtests: **one
`suite(...)` per tested unit, one `test(...)` per scenario inside it.**

### Unit tests — one `suite` per tested method/class

```scala
// src/test/scala/<pkg>/EncoderSpec.scala
import zio.test._

object EncoderSpec extends ZIOSpecDefault {
  def spec = suite("Encoder.encode")(
    test("returns empty string for empty input") {
      assertTrue(Encoder.encode("") == "")
    },
    test("preserves unicode") {
      assertTrue(Encoder.encode("café") == "café")
    },
    test("fails on invalid input") {
      assertZIO(Encoder.encodeZIO("\uD800").exit)(failsWithA[DomainError.InvalidInput])
    },
  )
}
```

Do **not** create separate top-level suites or separate spec files per scenario. All
scenarios for the same method live inside a single `suite`. For multiple methods on the
same class, nest one `suite` per method:

```scala
object UserSpec extends ZIOSpecDefault {
  def spec = suite("User")(
    suite("validate")(
      test("accepts valid email") { /* ... */ assertTrue(true) },
      test("rejects malformed email") { /* ... */ assertTrue(true) },
    ),
    suite("updateName")(
      test("updates non-empty name") { /* ... */ assertTrue(true) },
      test("rejects empty name") { /* ... */ assertTrue(true) },
    ),
  )
}
```

### Effectful tests — `assertZIO` and the test environment

```scala
object ClockServiceSpec extends ZIOSpecDefault {
  def spec = suite("ClockService.tick")(
    test("emits after the configured interval") {
      for {
        fiber  <- ClockService.tick(1.second).fork
        _      <- TestClock.adjust(1.second)
        result <- fiber.join
      } yield assertTrue(result == 1)
    },
  ).provide(ClockService.live)
}
```

### What "one suite per tested unit" means

- **Pure function** — one `suite` named after the function.
- **Method on a service/class** — one `suite` per method, nested under a `suite` named
  after the type.
- **HTTP route** — one `suite` per route, with a `test` per scenario.

Use `TestClock` / `TestRandom` / `TestConsole` for determinism instead of real time or
randomness. Reach for `@@ TestAspect.flaky`/`nonFlaky` to *characterize* flakiness, not
to hide it. The rule exists so that test reports group by *what is being tested*, not by
*scenario shape*.

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
  `NNN-description.md` (e.g. `001-fix-login-validation.md`, `002-add-rate-limit.md`).
  Pick the next number by checking the highest existing prefix across `plans/`,
  `plans/completed/`, and `plans/history/`.

- **Completed plans (`plans/completed/`)** — date prefix + zero-padded daily index
  (4 digits) + slug: `YYMMDD.NNNN.description.md`
  (e.g. `260422.0001.fix-login-validation.md`). `NNNN` resets to `0001` each day and
  increments for each additional completion on that day.

- **Archived plans (`plans/history/`)** — keep the original `NNN-` filename from `plans/`.

### Lifecycle

1. **Create** — before touching code, produce a plan file in `plans/` using the
   `NNN-slug.md` naming convention described above.
2. **Implement** — work through the tasks defined in the plan. The plan file stays in
   `plans/` while work is in progress.
3. **Complete** — once every acceptance criterion is met and `sbt scalafmtCheckAll`,
   `sbt compile`, and `sbt test` pass, rename and move the file to `plans/completed/`:
   ```bash
   mv plans/001-fix-auth.md plans/completed/260422.0001.fix-auth.md
   ```
4. **Archive** — if a plan is abandoned or superseded without being fully implemented,
   or if intermediate data / task execution logs need to be saved, move it to
   `plans/history/` instead.

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
- **Keep plans honest.** If implementation diverges from the plan, update the plan
  file before moving it to `completed/`.
- **Slug matches intent.** `002-add-rate-limit.md`,
  `003-migrate-doobie-to-quill.md`, not `004-task.md`.

## Agent Pipeline

All non-trivial tasks follow a three-stage pipeline using specialized agents. The
review stage fans out to **three `scala-reviewer` instances running in parallel**,
each with a distinct lens. A separate `scala-testdoctor` agent is invoked on-demand
whenever tests fail, at any stage.

```
User describes task
    ↓
1. scala-architect
    → Creates plan file at plans/NNN-slug.md (see Planning Workflow)
    ↓
2. scala-engineer
    → Implements the tasks defined in the plan
    ↓
3. scala-reviewer × 3 (run in parallel — single message, three tool calls)
    Lens A: correctness & tests — bugs, exhaustivity, error-channel
            discipline (typed E vs defects), fiber/resource leaks,
            edge cases, test coverage, test structure (one suite per
            unit), scenario completeness, deterministic time/random
    Lens B: security & operations — input validation, auth boundaries,
            secrets handling, injection (SQL, command), observability
            (logs, metrics, traces), log volume, operator/runbook UX
    Lens C: performance & architecture — allocations, blocking calls,
            fiber/Stream backpressure, layer boundaries, dependency
            direction, public service-trait contracts (breaking changes
            to R/E/A), interface scope, ZLayer composition discipline
    ↓
   Orchestrator synthesises all three reports, deduplicates findings,
   resolves conflicts (e.g. one reviewer flags as P0 what another
   accepts as a trade-off), and presents the merged punch list to the user.
    ↓
  ❌ P0/P1 found?  → Back to scala-engineer with the consolidated findings.
                             After fix, run ONE targeted reviewer pass on the changed
                             lines (not all 3 again) before re-approval.
  ⚠️  Tests failing?        → scala-testdoctor diagnoses and patches, then rerun the
                             targeted reviewer pass.
  ✅ All three approve?     → Orchestrator moves the plan: mv plans/NNN-slug.md
                             plans/completed/YYMMDD.NNNN.slug.md
```

### Agent responsibilities

| Agent | Owns | Output |
|-------|------|--------|
| `scala-architect` | Planning, decomposition, trade-offs | New plan file in `plans/` |
| `scala-engineer` | Implementation, tests for new code | Code + tests in the repo |
| `scala-reviewer` (×3, parallel) | Lens-specific verdicts, priority-ranked findings, patch sketches | Three independent review reports |
| `scala-testdoctor` | Triage of failing tests, minimal patches | Code/test fixes, re-run of `sbt test` |

The orchestrating agent (the main Claude session driving the pipeline) owns
synthesis: merging the three reports, resolving conflicting verdicts, deciding
which findings to act on, and moving the plan to `completed/` once everyone
signs off.

Priority scale used by reviewers: **P0 / P1 / P2 / P3**.

### Rules

- **No skipping stages.** Every task starts with the architect and ends with the three-reviewer fan-out.
- **Plan file first.** The architect MUST produce a plan file before any code is written. If a plan already exists for the task, update it rather than creating a new one.
- **Three reviewers, three lenses, one message.** All three `scala-reviewer` agents are launched in a single tool-call batch (multiple `Agent` blocks in one message) so they run in parallel. Each prompt names the lens explicitly and tells the agent what to SKIP (the other lenses) to avoid duplicated work.
- **No solo reviewer pass on first review.** Even for small changes the full three-lens fan-out is required, because the lenses catch genuinely different classes of issue (Lens A won't see ops/log-volume problems; Lens C won't see test gaps). Skipping lenses is what the orchestrator does AFTER a P0/P1 fix, not BEFORE the first verdict.
- **Lens prompts are self-contained.** Each reviewer's prompt must include: (1) the lens name, (2) what to focus on, (3) what to SKIP (so it doesn't restate other lenses), (4) the file list, (5) the deliverable shape (P0 / P1 / P2 / P3 with `file:line` + patch sketch), (6) the word cap (typically 600 words).
- **Re-review after fixes is single-pass.** Once an engineer addresses P0/P1 findings, the orchestrator runs ONE reviewer pass scoped to the changed lines, not the full fan-out. Re-running all three each iteration is expensive and rediscovers nothing.
- **Conflict resolution is explicit.** When reviewers disagree (one says P0, another says trade-off), the orchestrator chooses, names the rejected suggestion, and explains the reasoning to the user before moving on. The user has final say.
- **Orchestrator gates completion.** The plan moves to `plans/completed/` only after every reviewer's P0 and P1 findings are addressed (either fixed, or explicitly accepted with rationale). The rename uses the standard `YYMMDD.NNNN.slug.md` format.
- **`sbt scalafmtCheckAll`, `sbt compile`, and `sbt test` must pass** before review begins. If anything fails, hand the logs to `scala-testdoctor` first — reviewers should not waste time on a red tree.
- **Testdoctor is scoped.** It patches tests or the minimal production code needed to make the failure go away. It does not redesign or refactor.
