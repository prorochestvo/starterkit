---
name: go-performance
description: Go performance doctrine - measurement-first optimization, benchmarks, pprof profiling, allocation reduction, GC tuning (GOGC/GOMEMLIMIT), and escape analysis. Load when optimizing Go code, writing benchmarks, or reviewing performance-sensitive paths.
---

# Go performance

Distilled from *Efficient Go* (Bartłomiej Płotka). Efficiency is a requirement like any other: stated, measured, and tested — not vibes.

## Doctrine

- **Never optimize without a measurement and a goal.** The loop is: define the requirement (latency/throughput/memory budget) → measure → find the bottleneck → change one thing → measure again. An optimization without a before/after benchmark is a style change with risk.
- **Optimize at the right level, in order:** algorithm & data structure → code (allocations, copies) → runtime/GC tuning → hardware. An O(n²) fixed at the code level is effort wasted.
- **Readable first.** Optimize the 3% that profiling identifies as hot; everywhere else, clarity wins. Leave a comment with the benchmark delta on any code made uglier for speed.
- **Allocations are the usual suspect.** In Go services, GC pressure from allocation rate dominates most "CPU" problems. Reducing allocs/op frequently beats micro-optimizing instructions.

## Benchmarks

- `go test -bench=. -benchmem -run=^$ -count=10 ./pkg/` and compare with `benchstat` — single runs lie; report median ± variance.
- `b.ReportAllocs()`, `b.ResetTimer()` after setup, `b.Loop()` (Go 1.24+) or `for range b.N` as the loop.
- Prevent the compiler from optimizing the work away: assign results to a package-level `sink` variable.
- Benchmark realistic inputs and sizes (sub-benchmarks per size: `b.Run("n=1000", ...)`); micro-benchmarks on toy data mislead.
- Macro level: load-test the actual service (k6/vegeta) and watch RED metrics; micro-benchmarks don't capture GC interaction, connection pools, or contention.

## Profiling (pprof)

- CPU: `go test -cpuprofile` or `net/http/pprof` in services (`/debug/pprof/profile`); read with `go tool pprof -http=:8080`.
- Heap: `-memprofile` / `/debug/pprof/heap`; look at `alloc_space` for allocation-rate problems (GC pressure) and `inuse_space` for footprint/leaks.
- Goroutine profile for leaks (`/debug/pprof/goroutine?debug=1` — a monotonically growing count is a leak); mutex/block profiles for contention (enable with `runtime.SetMutexProfileFraction`/`SetBlockProfileRate`).
- Continuous profiling in production (Pyroscope/Parca/Cloud Profiler) beats artisanal reproduction: the hot path in prod is rarely the one you guessed.
- Execution tracer (`go tool trace`) when the question is "where does latency go" rather than "what burns CPU": scheduler stalls, GC pauses, blocked goroutines.

## Common wins (verify each with a benchmark)

- Preallocate: `make([]T, 0, n)` / `make(map[K]V, n)` when size is known; `strings.Builder` with `Grow`.
- Reuse: `sync.Pool` for large, frequently allocated, short-lived objects (buffers); reset-and-reuse slices (`s = s[:0]`) in loops.
- Avoid gratuitous copies: `[]byte`↔`string` round-trips, passing large structs by value on hot paths, `io.ReadAll` where streaming works.
- Interface boxing on hot paths: calls through `any`/small interfaces allocate and defeat inlining; keep hot paths concrete (generics can help).
- Escape analysis: `go build -gcflags='-m'` shows what escapes to heap; returning pointers to locals, closures, and interface conversions are the usual escapes.
- I/O: buffer (`bufio`) and batch (DB round-trips, syscalls); latency problems are more often round-trip counts than CPU.

## Runtime & GC

- `GOMEMLIMIT` (soft memory limit) + `GOGC` are the two knobs: containers should set `GOMEMLIMIT` to ~90% of the cgroup limit to avoid OOM kills while letting GC relax when there's headroom.
- `GOMAXPROCS` must respect container CPU quota (`automaxprocs` or explicit) — the default reads host cores and causes throttling in Kubernetes.
- Long GC pauses are almost always allocation rate, not GC tuning: fix allocs/op first, tune second.

## Review checklist

- [ ] Any claimed optimization ships with a before/after benchmark (`benchstat` output in the PR/plan).
- [ ] Hot paths identified by a profile, not intuition.
- [ ] No `sync.Pool`/unsafe/clever tricks on cold paths — clarity there.
- [ ] Service exposes `net/http/pprof` on an internal/admin port.
- [ ] Container deployments set `GOMEMLIMIT` and correct `GOMAXPROCS`.
