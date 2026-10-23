# Src Configuration

### Centralize environment variable names (R4)

Environment variable names are application policy constants, not inline
literals scattered through code. Define each once in the shared root
constants package and reference the constant everywhere.

### Consumers receive decoded settings, not raw DSNs (R5)

Constructors that need settings accept the typed data-source value of the
settings library chosen under R8, or an already-decoded value object. They
do not accept a raw DSN string and implement their own parser. Keep
env/config decoding at the composition boundary.

### Fail fast on required startup configuration (R6)

Parse and validate required configuration before the service begins
normal work. Missing or malformed required settings are startup
failures, not runtime surprises.

### Inject external identity from the composition root (R7)

Service names, notification hashtags/prefixes, user-agent strings, and
other app identity are supplied by `main`/bootstrap. Reusable packages
do not hardcode one application's identity.

### Non-secret settings come from the service's config file (R51)

A service reads non-secret settings (ports, timeouts, directories,
verbosity, limits) from its own config file (e.g. `<service>.toml`),
loaded by the composition root through one config package; code defaults
stay in the constants package (R20, R27). Build metadata injected with
`-ldflags` (version, time, hash) lives in that config package too, not as
package-level vars in `cmd/*/main.go`. Only secrets come from the
environment: keys, passwords, tokens, and database/broker/external-service
addresses (DSNs). The config package decodes into plain structs; the
composition root validates them (R6, R48), and application code receives
those structs and never reads the environment or flags itself. The config
package parses credentials (e.g. a service-account token, sender identity)
into plain values and imports no provider SDK; the provider client is
built from those values outside it.

## Shipped settings

### Every shipped settings file is complete (R42)

Each environment settings file lists every key the loader understands,
including values equal to code defaults. Ship a local settings file
beside environment files for workstation use; do not deploy it.

Committed secrets remain empty/placeholders. Add a test that decodes
every shipped file, rejects unknown keys, and fails when a loader field
is missing from a file.
