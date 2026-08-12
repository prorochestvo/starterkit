---
name: go-mistakes
description: Go mistakes that a linter cannot decide - slice aliasing, nil-versus-empty at API boundaries, JSON and time traps, resource and pool sizing, panic policy, and test design. Load when reviewing Go diffs or debugging surprising Go behavior. The mechanically enforceable half lives in stack-go:lint.
---

# Go mistakes that need a human

Distilled from *100 Go Mistakes and How to Avoid Them* (Teiva Harsanyi) plus
field experience, then filtered: **every rule a linter can decide has been
removed from this file.** What remains needs context, a boundary contract, or
knowledge of the deployment.

Before using this list, confirm the linter is green. Reporting a finding that
`golangci-lint` already printed wastes the reader's attention and teaches them
to skim.

## Already enforced — do not report these

These were review items once. They are now decided mechanically by
`stack-go:lint`; trust the tool and spend the attention elsewhere.

| Mistake | Enforced by |
|---|---|
| variable shadowing | `govet` (shadow) |
| `init()` doing real work | `gochecknoinits` |
| `make([]T, n)` then append | `makezero`, `prealloc` |
| nil check next to `len()` | `staticcheck` S1009 |
| `[]byte`/`string` round-trips | `unconvert`, `mirror`, `perfsprint` |
| mixed value and pointer receivers | `recvcheck` |
| named results, naked return | `nakedret` |
| nil concrete pointer returned as an interface | `nilnil`, `nilerr`, `nilnesserr` |
| `%v` where `%w` was meant | `errorlint` |
| silently dropped errors | `errcheck` |
| bare `break` inside select in a loop | `staticcheck` SA4011 |
| `defer` in a loop | `gocritic`, `revive` |
| `time.After` in a loop | `staticcheck` SA1015 |
| `WaitGroup.Add` inside the goroutine | `staticcheck` SA2000 |
| copying a mutex | `govet` (copylocks) |
| context stored in a struct | `containedctx` |
| HTTP body not closed | `bodyclose` |
| server without read/header timeouts | `gosec` G112 |
| string concatenation in a loop | ruleguard |
| `http.Client` without a timeout | ruleguard |
| `http.Error` without a return | ruleguard |
| `time.Time` compared with `==` | ruleguard |
| money in `float64` | ruleguard |
| logging and returning the same error | ruleguard |
| `time.Sleep` in tests | `forbidigo` |
| missing `t.Parallel()` / `t.Helper()` / `t.Context()` | `paralleltest`, `thelper`, `usetesting` |

## The pgx blind spot — check this by hand

`rowserrcheck` and `sqlclosecheck` understand `database/sql` only. A repository
layer on `jackc/pgx` has **no** automated coverage:

- Every `for rows.Next()` loop needs a `rows.Err()` check after it. Without one
  a connection dropped mid-iteration returns a short result set and a nil
  error — the caller sees "fewer rows" and never learns why.
- Every `Query` result needs a `defer rows.Close()`.
- A type-erasing wrapper such as `defer func(c interface{ Close() }) { c.Close() }(rows)`
  closes correctly but hides the fact from tooling. Prefer `defer rows.Close()`
  so the linter can see it.

## Data and boundaries

- **Slice aliasing.** Sub-slicing shares the backing array: mutations leak
  between slices, and a small sub-slice of a huge one pins the whole array.
  Appending to a sub-slice with spare capacity overwrites the parent's
  elements. Use a full slice expression `s[low:high:max]` or `copy` when
  independence matters. Whether independence matters is the judgment.
- **Nil versus empty slice.** `var s []T` is nil, `[]T{}` is not; JSON encodes
  them as `null` and `[]`. Pick deliberately at every API boundary and keep the
  choice consistent across endpoints — a client that special-cases `null` on
  one route and `[]` on another is a bug you shipped.
- **A map never shrinks.** Bucket memory is not released on delete. A map that
  grew to millions of entries keeps that footprint for the process lifetime.
  Recreate it, or store pointers, when the peak is far above the steady state.
- **Substrings pin the parent.** `s[:n]` of a huge string keeps the whole
  string alive. `strings.Clone` detaches it. Relevant when the slice outlives
  the parse.
- **Range copies the element.** `for _, v := range s` yields a copy; mutating
  `v` does nothing, and for a large struct the copy itself costs. Index when
  you mutate.
- **Bytes versus runes.** `s[i]` is a byte; `for i, r := range s` yields rune
  starts. Mixing them corrupts anything non-ASCII — which, on Kazakh and
  Russian input, is everything.

## Errors

- **Wrapping is an API decision.** `%w` makes the wrapped error part of your
  contract: callers may now match it with `errors.Is`/`errors.As`, and you
  cannot change it without breaking them. Use `%v` deliberately to cut the
  chain at a boundary. The linter enforces that you chose; it cannot tell you
  which choice was right.
- **Log or return, once.** The mechanical case is caught. The remaining
  judgment: logging *and* returning a wrapped error is sometimes correct — an
  operational breadcrumb at a half-state boundary that the caller also has to
  handle. Ask whether the log line tells an operator something the propagated
  error will not.
- **Errors from deferred calls.** `defer f.Close()` drops the error. On write
  paths that matters — a failed flush loses data — so capture it:
  `defer func() { err = errors.Join(err, f.Close()) }()`. On read paths it does
  not.
- **Panic policy.** Panic only for programmer errors: impossible states,
  invalid constants at init. Never for bad input, I/O, or anything a caller
  could reasonably retry.
- **Deferred argument evaluation.** Arguments to a deferred call are evaluated
  at `defer` time, not at execution. When the final value matters, close over
  the variable instead of passing it.

## Standard library traps

- **JSON into `map[string]any`.** Every number becomes `float64`; an `int64` ID
  past 2^53 is silently corrupted. Use typed structs or `json.Number`.
- **Embedded `time.Time`.** Embedding promotes `MarshalJSON` and hijacks the
  whole struct's encoding. Name the field.
- **Connection pool sizing.** Unlimited `MaxOpenConns` melts the database under
  load; too few starves the service. The right numbers come from the
  deployment — pgbouncer pool mode, instance size, expected concurrency — not
  from a default. Set all three of max-open, max-idle and conn-max-lifetime
  explicitly, and be able to say why.
- **Draining before close.** `bodyclose` proves the body was closed. It does
  not prove it was read: an unread body stops the connection from being reused.
  `io.Copy(io.Discard, resp.Body)` before close on any path that abandons a
  response early.

## Structure

- **Interface pollution.** The linters flag oversized and duplicated
  interfaces. They cannot tell you an interface should not exist yet. Define it
  where it is consumed, once a second implementation or a real test seam
  exists — not in anticipation.
- **Utility packages.** `util`, `common`, `helpers`, `base`: a name that says
  nothing holds code that belongs nowhere. Name packages by what they provide.
  A ban list catches the known names; it cannot catch `tools` or `shared`.
- **Embedding to inherit.** Embedding promotes the embedded type's entire
  method set into your public API. Do it when that promotion is the intent, not
  to save typing.

## Concurrency

See `stack-go:concurrency` for the doctrine. The judgment items:

- Every `go` statement has an owner, a stop condition, and a defined path for
  its error. Missing any of the three is a leak by construction, and no linter
  can see it.
- Fan-out is bounded whenever the input size is not fixed. Unbounded
  goroutine-per-item on user-controlled input is a denial of service you wrote
  yourself.
- Channel buffer sizes come from a stated requirement — burst absorption, a
  known rate mismatch. A buffer that "fixes" a deadlock is hiding one.
- `-race` catches only races that actually execute. A clean run is not proof.

## Tests

- A failing table case must identify itself: named subtests via
  `t.Run(tc.name, ...)`, not an index.
- Assertions target observable behavior, not internal state. A test that breaks
  on every refactor is measuring the implementation (see
  `knowledge:testing-doctrine`).
- One `Test*` function per tested method, scenarios as subtests inside it.
