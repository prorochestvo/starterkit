---
name: go-concurrency
description: Go concurrency doctrine - goroutine lifecycle ownership, channels vs mutexes, context propagation, cancellation, bounded concurrency patterns (worker pool, pipeline, fan-out/fan-in, semaphore), memory model, and race discipline. Load when writing or reviewing concurrent Go code.
---

# Go concurrency

Distilled from *Effective Concurrency in Go* (Burak Serdar) and the Go memory model. Concurrency is a correctness problem first and a performance tool second.

## Doctrine

- **Every goroutine has an owner and a stop condition.** Before `go f()`, answer: who waits for it, how is it told to stop, what happens to its result/error? A goroutine without all three answers is a leak by construction.
- **Concurrency is not parallelism.** Structure the program around independent concerns; the runtime decides parallelism. Do not add goroutines for speed before measuring (see `stack-go:performance`).
- **Don't communicate by sharing memory; share memory by communicating** — but honestly: a mutex protecting a struct field is simpler and faster than a channel pretending to be one. Channels are for *transfer of ownership*, signaling, and pipeline stages; mutexes are for *protecting state in place*.
- **Happens-before or it didn't happen.** Two goroutines touching the same variable need a synchronization edge (channel op, mutex, `sync.Once`, `WaitGroup.Wait`, atomic). "It worked in the test" is not a memory-model argument.
- **`-race` is mandatory** in tests and acceptable in staging. It only catches races that execute — absence of a report is not proof of absence; design for correctness, use the detector as a tripwire.

## Cancellation & context

- `context.Context` flows through call chains as the first parameter; it is never stored in a struct field (except request-scoped types created and dying with the request).
- Every blocking operation a goroutine performs must be interruptible: `select` on `ctx.Done()` alongside the channel op, pass ctx to I/O APIs, use `NewTimer` not bare `Sleep` in long waits.
- The function that creates a context with `WithCancel`/`WithTimeout` owns calling `cancel()` — always `defer cancel()`.
- Do not stuff values into context except true request-scoped cross-cutting data (trace IDs, auth principal). Config and dependencies go through parameters/constructors.

## Channel discipline

- The **sender closes**, never the receiver; close is a broadcast of "no more values", not a resource cleanup — it's fine to never close a channel that goroutines stop reading.
- Buffered channels: size the buffer from a reasoned requirement (burst absorption, decoupling rate mismatch), not superstition. Default is unbuffered; a magic buffer that "fixes" a deadlock is hiding one.
- A `select` with `default` is a poll; without is a block. Know which you wrote.
- `nil` channels block forever — useful to disable a `select` case dynamically, a bug everywhere else.

## Patterns (bounded by default)

- **Worker pool**: fixed N workers ranging over a jobs channel; close jobs to shut down; collect errors via a results channel or `errgroup`.
- **`errgroup.Group`** (`golang.org/x/sync/errgroup`): structured concurrency default — `g.Go` per task, first error cancels the group context, `g.Wait()` joins. Use `g.SetLimit(n)` to bound fan-out.
- **Pipeline**: stages connected by channels, each stage owns its output channel and closes it when input drains; propagate cancellation by selecting on `ctx.Done()` in every stage.
- **Fan-out/fan-in**: distribute work to N goroutines, merge results through a single channel closed after `wg.Wait()` in a separate goroutine.
- **Semaphore**: `chan struct{}` of capacity N (or `x/sync/semaphore`) to bound concurrent access to a resource.
- Unbounded goroutine-per-item on user-controlled input is a denial-of-service you wrote yourself.

## sync primitives

- `sync.Mutex`: keep critical sections small; never copy a struct containing one (pointer receivers for types embedding mutexes); no recursive locking — Go mutexes don't reenter.
- `sync.RWMutex` only when profiling shows read contention; it is slower than `Mutex` under low contention and invites subtle upgrade deadlocks.
- `sync.Once` for lazy init; `sync.WaitGroup`: `Add` before launching the goroutine, `Done` via defer inside it.
- `atomic` for counters/flags only; the moment two atomics must stay consistent with each other, you need a mutex.
- `sync.Map` is for append-mostly caches with disjoint key sets per goroutine — a locked `map` is the right default.

## Review checklist

- [ ] Every `go` statement: owner, stop signal, error path identified.
- [ ] Every channel: who sends, who receives, who closes, what capacity and why.
- [ ] Every `select` loop includes `ctx.Done()` (or has a documented reason not to).
- [ ] Fan-out bounded (`SetLimit`, pool, semaphore) when input size is not fixed.
- [ ] No shared mutable state without a synchronization edge; `-race` runs in CI.
- [ ] Blocking sends/receives can't deadlock on early return paths (defer close/cancel ordering).
