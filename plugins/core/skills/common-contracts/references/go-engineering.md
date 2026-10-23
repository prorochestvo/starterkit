# Go Engineering

### Interface assertions belong in tests (R1)

Every production implementation of an interface has a compile-time
assertion in tests, at the top of the `_test.go` paired with the file that
declares the interface, never in a shared contracts test file. Do not keep
duplicate assertions in production files. When that test file cannot
import the implementation without an import cycle, or the interface is
declared outside the repository (`io.Closer`, `http.Handler`), put the
assertion at the top of the implementing file's `_test.go` instead; for
an unexported consumer interface in another package, declare a test-only
mirror interface directly above the assertion (R41 in `go-layout.md`).

### Interfaces are consumer-local and minimal (R2)

Define an interface where it is consumed and include only methods that
consumer uses. Prefer unexported interfaces. Do not create `contracts`,
`ports`, `egress`, or similar dumping-ground packages just to hold
interfaces.

Exception: when an interface type itself appears in a cross-package
interface method signature, Go requires both sides to name the same
type. Export that port from the package that produces/owns it and use
that type. Prefer stdlib contracts such as `io.Closer` where applicable.

### Model domain concepts as types (R3, R24, R34)

Use named domain types instead of bare primitives when the value has
domain meaning, validation, a closed vocabulary, or when same-primitive
parameters can be transposed.

If two or more adjacent parameters share the same primitive type and
swapping them would compile but be wrong, replace them with distinct
named types or a struct.

A type used by a framework to make a decision must be built from
authoritative data, not a lossy projection that discards the
distinguishing information before the type is constructed.

## Naming and layering

### No redundant import aliases (R12)

Do not alias an import to the package's own declared name. Alias only
for a real collision or meaningful disambiguation.

### Names describe the concept and actual behavior (R13)

Package and symbol names describe what something is/does, not an
implementation mechanism or behavior it does not actually provide.
Renaming a public/conceptual surface is a design decision: propose the
change rather than silently rewriting vocabulary.

### Put concerns in the layer matching their role (R14, R44)

HTTP-only concerns are transport/middleware, not infrastructure. Shared
HTTP plumbing belongs under `internal/tools/rest/<name>`.
External-system adapters belong under `internal/integration/<name>`.
Project-agnostic utilities belong under `internal/tools/<name>`. Project
layer packages such as `application`, `gateway`, and `infrastructure`
remain explicit.

Do not split one concern into parallel packages that serve the same
role.

## Reuse and simplicity

### Prefer established libraries over reimplementation (R8)

Before hand-writing settings parsing, logging plumbing, or a third-party
API client, prefer the user's existing libraries and mainstream
libraries. If the `go-libraries` skill is available, check its preferences
before judging R8.

Do not silently swap libraries when behavior or dependencies change;
surface that as a design decision.

### No pass-through abstractions (R9)

A wrapper that only forwards to another function without adding policy,
adaptation, lifecycle, or meaningful semantics is noise. Inline it and
keep the better name.

A helper extracted only to avoid duplicating a few trivial operations
or an error-handling idiom (e.g. a deferred recover plus a log line) is
noise too, including as a package-level function. Inline it at each
caller and accept the duplication. A function earns its place by
encapsulating meaningful behavior. The trivial-helper ban in this paragraph does not
apply to the shared-check closure R47 in `go-layout.md` describes.

### General reusable logic gets a reusable home (R10)

Logic with genuine cross-project value belongs under a general shared
package such as `internal/tools/*` or a standalone module, even if it
currently has one client. Design the API for the reusable concept, not
the first caller.

This does not override the storage-ownership rule (R45 in
`src-go-engineering.md`): service storage stays inside the owning
service's `infrastructure` tree even when it looks reusable.

### Shared configuration packages hold data, callers decide (R48)

A configuration package shared by several services (env names, keys,
defaults) holds names, constants and plain helpers. Which values a
service reads, and how it interprets and validates them, lives in that
service's composition root. In that package, declare an error type only
when a caller inspects it with `errors.As`, and a sentinel error only
when a caller matches it with `errors.Is`; otherwise return a plain
error where it is produced. Reusable behaviour packages placed under
R10 or R14 are outside this rule.

### Inline pure test fixtures (R11)

Keep fixture data in the test when the code under test consumes data,
not files. Use `testdata/` only when file I/O/path behavior is part of
what the test verifies.

### Copy documentation with deliberately duplicated code (R38)

When duplication is intentional, copy the declaration's load-bearing
documentation with the code. Compare each copy against the source,
including its leading comment. If a copy intentionally differs, document
why.

### Test this repository's behavior, not a dependency's (R43)

Consumer tests verify how this code uses a dependency and handles its
output/errors. Do not write tests whose only purpose is to re-prove
stdlib or third-party behavior. If the dependency is the user's library
and lacks coverage, the test belongs in that library.

### Application tests run on in-memory doubles (R49)

Tests of a service's application layer (the package holding business
behaviour, e.g. `application`) use in-memory doubles (mocks or fakes) of
the repositories and clients it consumes: no container, network
connection, or `TestMain` that starts infrastructure.

Real stores (testcontainers or an external instance) are tested by the
infrastructure package that implements them; when those tests are
missing, add them there, not in `application`. This narrows the "use
the real managed dependency" rule of `knowledge:testing-doctrine` for
layered Go services.

## Comment casing

Go inline comments start with a lowercase word (user preference, not Go convention). Preserve literal casing of identifiers.
