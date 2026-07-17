---
name: go-mistakes
description: Catalog of common Go mistakes for code review and self-checking - shadowing, slice/map gotchas, string handling, error management, concurrency bugs, stdlib traps (time, JSON, SQL, HTTP), and testing pitfalls. Load when reviewing Go diffs or debugging surprising Go behavior.
---

# Common Go mistakes (review checklist)

Distilled from *100 Go Mistakes and How to Avoid Them* (Teiva Harsanyi) plus field experience. Use as a review sweep: scan the diff against each relevant section.

## Code & project organization

- **Variable shadowing** — an inner `:=` silently shadows an outer variable (classic: `client, err := ...` inside an `if`, outer `client` stays nil). Check every `:=` inside a block that reuses an outer name.
- **Utility packages** (`util`, `common`, `helpers`, `base`) — a name that says nothing holds code that belongs nowhere. Name packages by what they provide.
- **Interface pollution** — interfaces created before a second implementation or consumer exists. Interfaces live on the consumer side; return concrete types, accept interfaces.
- **`init()` doing real work** — I/O, config reads, global registration with error paths. `init` can't return errors and runs on import; keep it for trivial assignments or avoid it.
- **Getters/setters cargo-culted from Java** — export the field or design a real behavior method.
- **Embedding types to "inherit"** — embedding exports the embedded type's full method set as public API. Embed only when that promotion is the intent (e.g. `sync.Mutex` in an unexported struct is fine).

## Data types

- **Slice length vs capacity confusion** — `make([]T, n)` creates n zero values; appending to it grows past them. For an append-loop, `make([]T, 0, n)`.
- **Slice aliasing leaks** — sub-slicing (`s[low:high]`) shares the backing array: mutations leak between slices, and a tiny sub-slice of a huge slice pins the whole array in memory. Use full slice expressions `s[low:high:max]` or `copy` when independence matters.
- **`append` on a shared slice** — appending to a sub-slice with spare capacity overwrites the parent's elements. Same fix: three-index slicing or copy.
- **Nil vs empty slice** — `var s []T` is nil, `[]T{}` is not; JSON encodes them as `null` vs `[]`. Be deliberate at API boundaries.
- **Checking emptiness with `!= nil`** — use `len(s) == 0`/`len(m) == 0`: correct for both nil and empty.
- **Map never shrinks** — a map's bucket memory is never released after deletes; a map that grew to millions of entries keeps that footprint. Recreate the map or store pointers when this matters.
- **Comparing values with `==`** — panics on types containing slices/maps at runtime? No — fails to compile for slices/maps, but interfaces holding uncomparable types panic at runtime. Use `reflect.DeepEqual` (slow) or a custom/generated equality method; in tests use `cmp.Diff`/testify.
- **Floating-point money** — never `float64` for currency; use integer minor units or a decimal library. Compare floats with a tolerance, never `==`.

## Control structures

- **Range copies the element** — `for _, v := range s` gives a copy; mutating `v` does nothing. Index into the slice (`s[i].Field = ...`) to mutate.
- **Range evaluates the expression once** — `for i := range s { s = append(s, ...) }` does not loop forever, but `for i := 0; i < len(s); i++` with appends does. Know which you want.
- **Break/continue target in select/switch inside a loop** — a bare `break` inside `select`/`switch` breaks the select, not the loop. Use a label.
- **`defer` in a loop** — defers accumulate until function return: resource exhaustion in long loops. Extract the loop body into a function.

## Strings

- **Iterating bytes when you mean runes** — `s[i]` is a byte; `for i, r := range s` yields rune starts. Mixing them corrupts non-ASCII handling.
- **Concatenation in a loop** — quadratic. Use `strings.Builder` (with `Grow` when size is known).
- **Substring pins the parent** — like slices, `s[:n]` on a huge string keeps the whole string alive. `strings.Clone` to detach.
- **Useless `[]byte(s)`/`string(b)` round-trips** — each is a copy; the `bytes` package mirrors `strings`, use it directly.

## Functions & methods

- **Value vs pointer receiver mixed without intent** — mutation through a value receiver is lost. Default: pointer receiver when the method mutates, the type contains sync primitives, or the struct is large; keep one kind per type unless there's a reason.
- **Named result parameters hiding bugs** — a bare `return` after forgetting to assign leaves zero values; use named results only for documentation (multiple same-type results) or defer-modification.
- **Returning a nil concrete pointer as an interface** — `return nil, err` where the nil is a typed pointer makes the interface non-nil (`err != nil` is true with a nil *MyError inside). Return literal `nil` for the interface.
- **Defer argument evaluation** — arguments to a deferred call are evaluated at `defer` time, not at execution. Close over variables or pass pointers when the final value is needed.

## Error management

- **Wrapping discipline** — wrap with `%w` when the caller may need to match (`errors.Is/As`); use `%v` to deliberately break the chain at a boundary. Wrapping makes the wrapped error part of your API.
- **Handling an error twice** — log-and-return double-reports; handle once: either log it (and stop propagating) or return it (possibly wrapped), never both.
- **Ignoring errors silently** — if intentional, write `_ = f()` with a comment saying why. A bare call that drops an error looks like a bug forever.
- **Errors from deferred calls** — `defer f.Close()` drops the error; on write paths capture it (`defer func() { err = errors.Join(err, f.Close()) }()`).
- **Panic misuse** — panic only for programmer errors (impossible states, invalid constants at init); never for expected failures like bad input or I/O.

## Concurrency

See `stack-go:concurrency` for the full doctrine. Reviewer's short list:

- Goroutine launched with no defined stop condition or owner (leak by construction).
- `sync.WaitGroup.Add` called inside the goroutine instead of before launch (race with `Wait`).
- Copying a `sync.Mutex`/`sync.WaitGroup`/`sync.Cond` by value (embedding in a copied struct, value receiver, passing by value).
- Channel used where a mutex is honest (protecting a struct field) or vice versa (signaling with flags + sleep).
- `context.Context` stored in a struct instead of flowing through calls; `context.Background()` deep in call chains that should propagate cancellation.
- Appending/reading a shared slice or map from multiple goroutines without synchronization — `-race` in tests is mandatory, and absence of a race report is not proof of absence.
- `errgroup`/worker pool without bounding concurrency (unbounded goroutine-per-item fan-out on user-controlled input).

## Standard library traps

- **`time.After` in a loop/select** — allocates a timer per iteration that is only GC'd on fire; use `time.NewTimer`/`Ticker` with `Reset`/`Stop`.
- **Monotonic vs wall clock** — `time.Since`/`Sub` use the monotonic clock (good); serialized/parsed timestamps lose it. Don't compare a parsed time to `time.Now()` with `==`; use `.Equal`.
- **JSON: `any` maps and number types** — unmarshaling into `map[string]any` turns all numbers into `float64`; large int64 IDs corrupt. Use typed structs or `json.Number`.
- **JSON: embedded `time.Time`** — embedding promotes `MarshalJSON` and hijacks the struct's encoding. Name the field.
- **`database/sql`: forgetting `rows.Err()`** — a loop that ends early may hide an iteration error; always check after the loop, and always `defer rows.Close()`.
- **`database/sql` pool defaults** — unlimited `MaxOpenConns` and small idle pool melt databases under load; set `SetMaxOpenConns`, `SetMaxIdleConns`, `SetConnMaxLifetime` explicitly.
- **HTTP: response body must be read and closed** — `defer resp.Body.Close()` and drain (`io.Copy(io.Discard, resp.Body)`) before close if not fully read, or the connection can't be reused.
- **HTTP: default client has no timeout** — `http.Client{}` waits forever. Set `Timeout` (and transport-level timeouts for fine control). Same for servers: `ReadTimeout`/`WriteTimeout`/`IdleTimeout` on `http.Server`.
- **`http.Error` doesn't return** — forgetting `return` after writing an error response continues the handler and double-writes.

## Testing pitfalls

- Time-dependent tests using real `time.Sleep` — flaky by design; inject a clock or synchronize on events.
- Table tests where a failing case doesn't identify itself — use named subtests (`t.Run(tc.name, ...)`).
- Tests asserting on internal state instead of observable behavior — brittle against refactoring (see `knowledge:testing-doctrine`).
- Forgetting `-race` locally and discovering races in CI or production.
