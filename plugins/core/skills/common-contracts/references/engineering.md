# Engineering

### `configs/` and `scripts/` have narrow jobs (R40)

`configs/` holds configuration and first-run/deployment setup.
`scripts/` holds repeatable operational scripts. Neither is a home for
Go source or spent one-off migration artifacts.

## Correctness and verification

### Unit-sensitive tests require divergent fixtures (R25)

If a contract distinguishes bytes/runes/UTF-16 units, cents/dollars,
seconds/milliseconds, etc., use a fixture where the competing units
produce different values and assert that the fixture actually diverges.
Mutation-test the wrong unit when practical.

### Fail-closed guards must be proportionate (R26)

If the process can safely repair the required state, repair it, re-read
the state, and fail only if it remains wrong. Do not turn a repairable
condition into a full outage.

Before privileged path repairs, protect against symlink traversal; do
not imply a race is closed when it is not. Repairs must be observable to
operators.

### Operational limits are configurable defaults (R27)

Timeouts, quotas, retention windows, concurrency limits, and similar
operational policy ship with a default but remain configurable without
rebuilding.

### Test seams are not configuration (R28)

A parameter whose documented meaning is "zero = default" but whose only
non-default caller is a test is a test seam disguised as configuration.
Remove it or make it real configuration with a production use case.

### Cache failures as well as successes when protecting an upstream (R29)

A read-through cache that suppresses repeated successful upstream calls
but retries every failure can stampede a failing dependency.
Negative/error results need an appropriate bounded cache/backoff policy
too.

### Do not trust early-exit pipeline status under `pipefail` (R33)

When a pipeline ends in `grep -q`, `head`, `read`, or another
early-exiting consumer, do not treat the pipeline's status as the
producer's verdict under `pipefail`; SIGPIPE can make a successful
producer look failed. Capture producer output/status separately or
explicitly neutralize the early-exit stage where appropriate.
