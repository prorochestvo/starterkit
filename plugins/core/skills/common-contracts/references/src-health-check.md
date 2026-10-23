# Health-check contract

Every new long-running service ships both: - `/ping`: liveness only; no
dependency work; cheap and normally `200`. - `/health/check`: readiness;
verifies whether the service can actually do its job.

A hardcoded readiness `ok` is not acceptable.

An existing service missing either endpoint: flag the gap in the report;
do not retrofit it uninvited. Adding the pair to an existing service is
its own task, asked for or planned, not a side effect of unrelated work.

## Dependency contract

Each external dependency owns a cheap, real, read-only health probe and
a stable unique name. The inspector depends only on a minimal interface
such as:

``` go
type service interface {
    Name() string
    CheckUP(context.Context) error
}
```

Examples: - SQL: connection ping plus a trivial query when needed to
prove queries work. - Repository: a real read in a rolled-back/read-only
path that proves required schema/access. - Messaging bot API: cheapest
authenticated identity call. - External API/AI: cheapest authenticated
probe. - Registry: check members and aggregate failures.

Do not mutate application state during health checks.

## Inspector

The aggregator: - has a whole-sweep timeout; - checks every registered
dependency even when one fails; - reports each dependency separately as
`ok` or an error reason; - treats a panic as an unhealthy response
rather than crashing the process; - accepts dependencies explicitly at
construction.

A slow/dead dependency must not hang the endpoint.

## Cost and freshness

Cheap local dependencies may be checked on every readiness call.
Paid/rate-limited external providers must not be multiplied by monitor
polling: cache their last health result for a bounded interval (roughly
hours, not days) and report its age.

Do not persist health verdicts as history. Monitoring/history belongs to
the monitoring system, not the service.

## Response and exposure

Return a machine-readable per-component report and an overall
healthy/unhealthy result. Keep component names stable.

Do not leak credentials, DSNs, tokens, raw secret-bearing URLs, or
internal sensitive values through dependency errors; apply the common
redaction contract.

Expose detailed readiness only where operationally appropriate; protect
it if the report reveals internal topology. Liveness should remain
simple.

## Review checklist

-   Both `/ping` and `/health/check` exist.
-   Readiness probes real dependencies, not constants.
-   Probes are read-only, bounded, and isolated.
-   One failure does not skip the rest.
-   Expensive providers are rate/cost bounded.
-   Errors are useful but secret-safe.
-   The endpoint cannot crash or hang the service.
