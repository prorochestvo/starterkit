---
name: go-conventions
description: Go project conventions - code style, file declaration order, code organization principles, error-handling contract, test structure, godoc, and build hygiene. Load before writing, placing, or reviewing any Go code.
paths:
  - "**/*.go"
  - "**/go.mod"
---

# Go conventions

Project `CLAUDE.md` overrides anything here. These are the defaults for every Go repo.

## Style essentials

- Idiomatic Go: early returns, short functions, meaningful names, `context.Context` as the first parameter where appropriate.
- Wrap errors with `%w` and match with `errors.Is`/`errors.As`; never compare error strings.
- Never discard errors with `_` in production or test code. Exceptions: `fmt.Fprint*` to loggers, `Rollback()` in error-recovery paths, `.Close()` in `defer`/`t.Cleanup`.
- Comments start lowercase and explain the non-obvious *why*, never narrate what the code plainly says. No `// --- section ---` divider comments.
- Avoid premature interfaces: define interfaces where they are consumed, not where types are implemented, and only when a second implementation or a test seam actually exists.
- `CGO_ENABLED=0` for all build/test commands unless the project explicitly needs CGO.

## File declaration order

Order top-level declarations so the public surface sits on top and private internals at the bottom. For a file built around one object:

1. Exported `const`/`var` and the `New<Object>` constructor(s).
2. The object's struct definition.
3. The object's methods (prefer alphabetical).
4. Unexported `const`/`var`.
5. Auxiliary unexported support types.
6. Unexported functions/helpers (prefer alphabetical).

Multiple structs in one file: primary struct's block first; two large objects in one file usually means the file should be split. Files with no central object follow the same spirit: exported surface on top, helpers at the bottom. A file violating this order is a finding to fix — apply on every `*.go` edit.

## Code organization principles

**Placement follows consumption, not aspiration.**
- Code shared by multiple binaries → shared tree (`internal/`).
- Code with exactly one consumer → next to that consumer (`cmd/<binary>/`), not the shared tree.
- `internal/` over `pkg/` unless a real out-of-module consumer exists. Never keep something shared because it is "reusable in principle" — check who actually imports it.

**Deduplication is not a goal.**
- Distinguish coincidental similarity (must stay free to diverge → duplicate the trivial lines) from a genuine cross-cutting invariant (→ centralize once).
- No shared `bootstrap`/`startup`/`wiring` layer across binaries — inline startup per entry point so each stays free to diverge.
- Before extracting a helper, check whether the shared thing is already a one-line call — if so, don't wrap it.

**Business logic is organized by concern, not by launcher.**
- Packages are judged by being simple and isolated, regardless of which binary runs them. Never reorganize by runtime-vs-operator, deployment, or consuming binary.

**Test-only code lives in `_test.go`, never in a production file.**
- A symbol whose only compile-time consumer is a test (fake/stub/mock, test helper, an option constructor called solely from tests) belongs in a `_test.go` file — Go excludes those from `go build`, so the suffix is the boundary that keeps scaffolding out of the shipped binary.
- The criterion is **consumption at compile time, not intent**: a field/type the production path reads stays in the production file even if only tests ever set it; the setter/constructor only tests call moves to `_test.go`.
- White-box helpers live in the `_test.go` beside their tests; `export_test.go` exists only to expose unexported symbols to an external `<pkg>_test` package — never as a parking lot. Cross-package test helpers follow the dedup rule: duplicate trivial helpers per package; centralize only a genuinely heavy fixture.

## Error-handling contract (default pattern)

Separate user-facing errors from internal failures:

- A dedicated public-error type (e.g. `internal.PublicError`, created via `internal.NewPublicError("...")`) is the **only** mechanism for surfacing safe, human-readable messages. Create it at the point where the error arises (usually the service layer).
- Everything else returns a plain wrapped error; the controller/boundary translates it to one generic fallback constant (`"Something went wrong. Try again later."`).
- Every test exercising an error branch asserts: (1) a response was actually sent; (2) the text equals the public error's message when it is one; (3) the text equals the fallback constant otherwise.

## Test structure

- `github.com/stretchr/testify` (`assert` + `require`); run with `-race`.
- **One `Test*` function per tested method/function; scenarios as `t.Run` subtests inside it.** `TestEncode` with subtests — never `TestEncode_Empty`, `TestEncode_Unicode` as separate top-level tests. Methods on a type use `TestType_Method`.
- `t.Parallel()` on top-level tests and subtests where there is no shared mutable state; `t.Helper()` in helpers; `t.Context()` where a context is needed.
- Every mock/stub struct in test files carries a compile-time check: `var _ InterfaceName = (*mockStruct)(nil)`.
- `Benchmark*` for performance-critical paths.

## Godoc

Every exported identifier gets a doc comment starting with its name and ending with a period. Each package has exactly one `// Package <name> ...` declaration; `cmd/*` entry points use `// Command <name> ...`. Skip comments that would only restate the signature. Document concurrency guarantees, public-vs-plain error behavior, lifecycle contracts ("caller must Close"), and sentinel error conditions. Preserve existing why-comments verbatim. Do not bulk-comment unexported helpers.

## Build hygiene

- Binaries go to `./build/` (`go build -o ./build/<name> ./cmd/<name>`), scratch files to `./tmp/`, runtime logs to `./logs/` — never the repo root.
- Migrations: schema is mutated only by a dedicated migrator binary; service binaries verify schema currency at startup and fail fast if stale. Migration filenames are immutable once applied anywhere shared; new work is additive-only.
- Reference table/column names through `const` declarations in the repository layer so schema renames surface at compile time, not as runtime "no such column".
