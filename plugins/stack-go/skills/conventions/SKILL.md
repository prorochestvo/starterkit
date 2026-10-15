---
name: go-conventions
description: Go project conventions that need judgment - code placement, deduplication policy, the error-handling contract, test-code boundaries, and build hygiene. Load before writing, placing, or reviewing any Go code. The mechanically enforced conventions live in stack-go:lint.
paths:
  - "**/*.go"
  - "**/go.mod"
---

# Go conventions

Project `CLAUDE.md` overrides anything here. These are the defaults for every
Go repo.

**Rules a linter decides are not repeated here.** Style, declaration order,
godoc, error discipline, and test scaffolding are configured once in
`stack-go:lint` and enforced by `golangci-lint`. If a convention below is not
in this file, check whether the linter already owns it before adding it.

## Enforced mechanically

| Convention | Enforced by |
|---|---|
| errors wrapped with `%w`, matched with `errors.Is`/`As` | `errorlint`, `err113` |
| no discarded errors, with the documented exceptions | `errcheck` |
| type first, then its constructor, then methods; exported before unexported | `funcorder`, `decorder` |
| godoc on exported identifiers, sentences ending in a period | `godoclint`, `godot`, `revive` |
| `t.Parallel()`, `t.Helper()`, `t.Context()` | `paralleltest`, `tparallel`, `thelper`, `usetesting` |
| correct testify assertions | `testifylint` |
| no section-divider comments | `lint-checks.sh` |
| compile-time interface assertion on every mock | `lint-checks.sh` |

## File declaration order

The order follows the standard library rather than a house rule: **the type
declaration comes first, its `New<Object>` constructor after it, then its
methods, exported before unexported.** `bytes.Buffer`, `bufio.Reader` and
`http.ServeMux` all do this, and it is what `funcorder` enforces by default.

An earlier house rule put the constructor above the struct, on the reasoning
that the public surface belongs at the top. It was dropped: for an exported
type the declaration *is* the top of the public surface, and every Go reader
and generator expects to find it first.

Existing files are not migrated in bulk. The rule is enforced on new code
through the linter baseline; a file moves to the new order when it is opened
for other reasons.

Two parts of the ordering rule are **not** machine-checked and stay a review
item: methods ordered alphabetically within their block, and the judgment that
a file holding two large objects should be split.

## Style essentials

- Idiomatic Go: early returns, short functions, meaningful names,
  `context.Context` as the first parameter where appropriate.
- Comments explain the non-obvious *why*, never narrate what the code plainly
  says. The exception is linter-mandated doc comments, which follow the
  language convention even when they restate the name.
- `CGO_ENABLED=0` for all build and test commands unless the project genuinely
  needs CGO.

## Code organization principles

**Placement follows consumption, not aspiration.**

- Code shared by multiple binaries → shared tree (`internal/`).
- Code with exactly one consumer → next to that consumer (`cmd/<binary>/`), not
  the shared tree.
- `internal/` over `pkg/` unless a real out-of-module consumer exists. Never
  keep something shared because it is "reusable in principle" — check who
  actually imports it.

**Deduplication is not a goal.**

- Distinguish coincidental similarity, which must stay free to diverge, from a
  genuine cross-cutting invariant. Duplicate the trivial lines; centralize the
  invariant.
- No shared `bootstrap`/`startup`/`wiring` layer across binaries — inline
  startup per entry point so each stays free to diverge.
- Before extracting a helper, check whether the shared thing is already a
  one-line call. If it is, wrapping it adds a name and removes nothing.

**Business logic is organized by concern, not by launcher.** Packages are
judged by being simple and isolated, regardless of which binary runs them.
Never reorganize by runtime-versus-operator, by deployment, or by consuming
binary.

**Layer boundaries are configuration, not folklore.** Once a project has
layers, express them as `depguard` rules keyed on file path — services must not
import `net/http`, domain must not import `database/sql`. A boundary that lives
only in a document is a boundary that erodes.

## Test-only code lives in `_test.go`

A symbol whose only compile-time consumer is a test — fake, stub, mock, test
helper, an option constructor called solely from tests — belongs in a
`_test.go` file. Go excludes those from `go build`, so the suffix is the
boundary that keeps scaffolding out of the shipped binary.

The criterion is **consumption at compile time, not intent**: a field the
production path reads stays in the production file even if only tests ever set
it; the setter only tests call moves to `_test.go`.

White-box helpers live in the `_test.go` beside their tests. `export_test.go`
exists only to expose unexported symbols to an external `<pkg>_test` package,
never as a parking lot. Cross-package helpers follow the dedup rule: duplicate
trivial ones per package, centralize only a genuinely heavy fixture.

## Error-handling contract

Separate user-facing errors from internal failures:

- A dedicated public-error type — `internal.PublicError`, built via
  `internal.NewPublicError("...")` — is the **only** mechanism for surfacing
  safe, human-readable messages. Create it where the error arises, usually the
  service layer.
- Everything else returns a plain wrapped error; the controller or boundary
  translates it into one generic fallback constant.
- Every test exercising an error branch asserts three things: that a response
  was actually sent, that the text equals the public error's message when it is
  one, and that it equals the fallback constant otherwise.

No linter can check this: whether a given message is safe to show a user is a
security judgment about the content, not the type.

## Test structure

- `github.com/stretchr/testify` (`assert` + `require`), run with `-race`.
- **One `Test*` function per tested method, scenarios as `t.Run` subtests
  inside it.** `TestEncode` with subtests — never `TestEncode_Empty` and
  `TestEncode_Unicode` as separate top-level functions. Methods on a type use
  `TestType_Method`.
- `Benchmark*` for performance-critical paths.

## Build hygiene

- Binaries go to `./build/` (`go build -o ./build/<name> ./cmd/<name>`),
  scratch to `./tmp/`, runtime logs to `./logs/` — never the repo root.
- Migrations: schema is mutated only by a dedicated migrator binary; service
  binaries verify schema currency at startup and fail fast if stale. Migration
  filenames are immutable once applied anywhere shared; new work is
  additive-only.
- Reference table and column names through `const` declarations in the
  repository layer, so a schema rename surfaces at compile time rather than as
  a runtime "no such column".
