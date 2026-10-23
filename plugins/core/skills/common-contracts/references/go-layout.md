# Go Layout

### Production files use one declaration order (R16)

Top to bottom: 1. package doc + `package`, imports; 2. exported `const`,
then exported `var`, except enum values that belong with their named
type; 3. per concrete type: type → constructor(s) → enum constants →
exported methods → unexported methods; then exported types without
constructors; 4. exported interfaces; 5. unexported `const`, then
unexported `var`; 6. unexported support types/interfaces; 7. unexported
helpers.

For `package main`, `main()` and `init()` come immediately after
imports.

Preserve relative order inside groups; do not alphabetize. A layout-only
change is movement-only: do not combine it with renames/content edits,
and keep `//nolint:` directives attached to their targets.
Build-tag-separated files are ordered independently.

### Declare each type on its own (R46)

Write one `type` declaration per type. Do not group types in a
`type (...)` block. Generated files with the standard
`// Code generated ... DO NOT EDIT.` header are exempt.

### Call arguments: one line, or one per line (R50)

Write a call on one line when it has three or fewer arguments and none
is a function call or operator expression. Otherwise put each argument
on its own line. Exception: a call in an `if v, err := f(...); cond {`
header is exempt from this rule.

### Test files mirror production structure (R17, R41)

Every `X_test.go` has a production counterpart `X.go` and mirrors its
declaration order. Exempt: `main_test.go` holding only `TestMain`,
`export_test.go` holding only test-only exports of package internals,
`example_test.go` holding only `Example*` functions, and
integration/harness tests (below). Merge any other test file with no
counterpart into the `_test.go` of the file that defines the tested
code. Layout: 1. interface assertions (R1); 2. `Test*` functions in
production-symbol order; 3. test-only contracts; 4. test-only
constants/vars; 5. helpers.

A test-only interface used only by an immediately adjacent compile
assertion may sit directly above that assertion. Integration/harness
tests that exercise a composition rather than one production file may
use logical grouping.

Use descriptive subtest names, never ordinal names.

Add `t.Parallel()` to top-level tests/subtests when legal. Keep a test
serial, with `// not t.Parallel() — <reason>`, when it uses
`t.Setenv`/`t.Chdir`, process-global mutable state, an exclusive OS
resource, shared mutable fixtures, or accumulated cross-subtest state.
Validate parallelism changes with the race detector and repeated runs.

### Explicit subtests, not case tables (R47)

Fixed cases of one production symbol are named subtests of its
`Test<Symbol>` function, one `t.Run` per case, even when more verbose;
not separate top-level `Test` functions and not a loop over a case
table. A case table is any list of cases written by hand, including one
assigned to a variable, returned by a helper, or loaded from a fixture
file. When subtests share checks, put them in a closure declared inside
the test function that takes the subtest's `*testing.T` as a parameter,
calls `t.Helper()` on it, and never uses the enclosing test's `t`:

```go
func TestParse(t *testing.T) {
	check := func(t *testing.T, in, want string) {
		t.Helper()
		if got := Parse(in); got != want {
			t.Errorf("Parse(%q) = %q, want %q", in, got, want)
		}
	}
	t.Run("lowercase input", func(t *testing.T) { check(t, "a", "A") })
	t.Run("empty input", func(t *testing.T) { check(t, "", "") })
}
```

Loops over inputs the test discovers at run time (a directory listing,
the registered handlers) and `for range N` repetition are not case
tables.

## Composition and placement

### Composition roots use explicit parameters (R18)

Do not introduce functional options, test-only flags, or production
branches solely to inject fakes into a single-caller composition root.
Prefer explicit parameters. Functional options are justified only by a
genuinely broad/growing API.

### Bootstrap returns finished objects (R19)

Startup/bootstrap performs fallible setup and returns ready-to-use
objects rather than raw strings or intermediate option bags. Name the
function for what it actually does. Keep pure parsing/validation/path
decisions in separately testable helpers.

### Application policy constants live in the shared root constants package (R20)

Defaults, env names, policy timeouts/limits, and policy lists belong in
the shared root constants package, one file per concern. Keep that
package stdlib-only.

When a security/enforcement package owns behavior, move only the literal
policy data; do not dissolve the enforcing façade.

### Version names must exist on the wire (R31)

Do not name a package/path/API `vN` unless that version is part of the
external protocol/routing/schema contract. Internal organization alone
does not justify a fake version boundary.

### Transport integrations split by responsibility (R23)

Keep transport concerns separated: - infrastructure/client: talks to the
external system; - gateway/adapter: translates transport events/data
into application concepts; - application: business behavior.

A file mixing transport SDK mechanics, mapping, and business decisions
is a finding.

### Service `main` only starts the service (R39)

`cmd/*/main.go` owns composition/startup, not maintenance modes, one-off
migrations, ad-hoc subcommands, or unrelated package-level mutable
state. Put operational commands in dedicated binaries/tools.
