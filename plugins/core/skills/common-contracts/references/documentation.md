# Documentation

### `AGENTS.md` is a map, not a manual (R21)

Keep a project's `AGENTS.md` concise: project map, commands, important
local overrides, and tripwires. `CLAUDE.md` is a committed relative
symlink to it, never a second file. Put deep reusable procedure/standards
in on-demand skills/contracts rather than duplicating them into every
project.

### Comments may claim only enforced properties (R35)

Security/guard comments, error text, and test messages must describe
exactly what the code enforces, including caller/deployment assumptions.
Avoid unjustified "any", "all", "never", "only". Narrow the claim or
strengthen the code; do not leave a false protection claim.

## Docs, specs, README, and code comments

- Docs and specs (README, `docs/`, `.agents/specs/`) state current facts only: no possible problems, alternatives, "if X is restored", "check before relying on it", or pending work — those live in plans. An open question is settled with the owner before the spec is written; a spec is reread for months, and a speculative note there outlives its truth.
- A README says what the project is and the non-obvious specifics of using it: what breaks if a step is skipped, what an env var actually controls. No decision rationale (plans / ADRs / commit bodies own that), nothing derivable from the repo tree, no empty "Overview" filler.
- Code comments: English, and only the non-obvious *why* — never narrate what the code plainly says. Exception: linter-mandated doc comments (godoc/dartdoc on exported identifiers) keep the language convention's form and state purpose or usage, in one brief line when the name and signature already say the rest; never implementation, history, or which callers use it. Preconditions and enforced guarantees are usage, not implementation; on security/guard comments R35 governs. Identifiers keep their literal casing everywhere.
