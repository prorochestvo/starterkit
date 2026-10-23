# Security

### Preserve redaction across refactors (R15)

A refactor, constructor change, or library swap must preserve existing
secret-redaction guarantees and their regression tests. Never assume a
replacement library's errors are secret-free; verify.

### Redaction must be total across every rendering path (R22)

Once a value is withheld, no error wrapping, formatter, validator,
alternate branch, or helper may reintroduce it.

Rules: - Do not wrap an error that quotes the secret after printing a
redacted form of the same value. - Do not trust helpers such as URL
redactors without verifying every credential-bearing component they
leave visible. - Shape/regex validation proves format, not provenance; a
token may look like a safe identifier or URL. - Centralize both the
redaction mechanism and the decision about whether a value may be
rendered. - Prefer a secret type whose normal rendering is safe when
call-site discipline has repeatedly failed. - Security enforcement
should allow known-safe reveal sites rather than maintain a denylist of
known-bad sinks. - Tests cover success and failure/rendering branches
and assert the raw secret is absent.

When a library error includes raw input, unwrap to a safe reason or
replace it with a generic reason before logging.
