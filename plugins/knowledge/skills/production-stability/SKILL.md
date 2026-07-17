---
name: production-stability
description: Production stability patterns - timeouts, retries with backoff and jitter, circuit breakers, bulkheads, backpressure, idempotency, health checks (liveness vs readiness), and graceful shutdown. Load when writing anything network-facing, designing integrations, or reviewing operational readiness.
---

# Production stability

Distilled from *Release It!* (Michael Nygard). Axiom: **every external call will eventually hang, fail, or lie** — the design question is what happens then. Stability antipatterns kill systems through resource exhaustion, not through the original error.

## Failure modes to design against

- **Integration point without a timeout** — the number-one killer. A hung remote call holds a thread/goroutine/connection; under load, held resources exhaust and the caller dies of someone else's slowness.
- **Cascading failure** — a slow downstream propagates upward as *your* slowness. Slow is worse than down: down fails fast, slow accumulates.
- **Blocked resource pools** — one stuck consumer starves everyone sharing the pool (DB connections, worker pools).
- **Unbounded queues and result sets** — "it can't grow that big" is a promise load will break. Every queue bounded; every query LIMITed or paginated.
- **Retry storms / self-inflicted DDoS** — synchronized retries after a blip finish off the recovering service.
- **Dogpile** — cache expiry stampeding the backend (single-flight/lock the recompute).

## Stability patterns

- **Timeouts, everywhere, deliberate.** Every network call has an explicit timeout derived from its caller's budget (an endpoint with a 2s SLO cannot make three sequential 1s calls). Defaults of "no timeout" (many HTTP clients, DB drivers) are bugs.
- **Retries: only idempotent ops, bounded attempts, exponential backoff + jitter,** and only at ONE layer (retry at every layer multiplies: 3 layers × 3 attempts = 27 calls). Respect `Retry-After`. A retry budget (max % of traffic as retries) beats per-call heroics.
- **Circuit breaker** on integration points that matter: after N consecutive failures, fail fast without calling; probe occasionally (half-open); pair with a fallback (cached value, degraded response, honest error). Breaker state changes are logged/metriced — they're incident telemetry.
- **Bulkheads**: partition resources so one dependency's failure can't starve another — separate connection pools/worker pools per downstream, per-tenant quotas, container-level isolation.
- **Backpressure over buffering**: when overloaded, push back (bounded queue + reject/shed with 429/503 early at the edge) instead of absorbing until collapse. Load-shed cheap and early beats dying expensively late.
- **Idempotency**: consumers see at-least-once delivery in any retried/queued system. Idempotency keys on mutating APIs; dedup on the consumer side; design handlers so processing a message twice is harmless (see `knowledge:data-systems`).
- **Fail fast**: validate what you need before doing expensive work; if a required dependency is down (breaker open), answer immediately.

## Health & lifecycle

- Two endpoints with different jobs:
  - **Liveness** (`/ping`): "process is alive" — touches no dependency, always 200 unless the process should be restarted.
  - **Readiness** (`/health/check`): "can do real work" — real per-dependency probes (DB, external APIs, queues), 200 only when all healthy. A hardcoded OK is a lie that turns outages into mysteries.
- Probes are **cost-bounded**: cheap local dependencies probed live; paid/rate-limited external APIs at most once per 2–3 hours with the cached result and its age served in between.
- **Graceful shutdown**: stop accepting new work, drain in-flight within a deadline, then exit. In-flight work lost on SIGTERM is a data bug, not an ops detail.
- Startup: fail fast on invalid config (missing env = immediate fatal, not a limping process).

## Observability minimum

- Logs: structured, with request/correlation IDs crossing service boundaries; error logs carry enough context to act (what operation, what input class, what downstream). Log volume is a cost — no per-item info logs in hot loops.
- Metrics: RED per endpoint (rate, errors, duration histogram) + saturation of every pool (connections, workers, queue depth) + breaker states. Alert on symptoms (SLO burn), page only on user impact.
- Every timeout/retry/breaker decision observable: when the system degrades, the *why* must be readable from telemetry, not reconstructed.

## Review checklist

- [ ] Every network call: explicit timeout, derived from the caller's budget.
- [ ] Retries: idempotent-only, bounded, jittered backoff, single layer.
- [ ] Every queue/pool/result set bounded; overload path defined (shed/reject, not absorb).
- [ ] External integration points have a breaker or a documented reason not to.
- [ ] Liveness + readiness endpoints per doctrine above; probes cost-bounded.
- [ ] Graceful shutdown drains in-flight work.
- [ ] Mutating endpoints idempotent or idempotency-keyed.
