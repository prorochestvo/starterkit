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
- A doc under `docs/` is written for a person who reads it once: state the essence of the problem, question, or decision and what follows from it, as briefly as clarity allows, so the reader reaches the end. Do not describe the code (the code and specs hold that) or carry history (plans and commit bodies hold that). A doc is not a spec: where agent-facing material goes is set in `task-management` (`references/plans.md`).
- A README says what the project is and the non-obvious specifics of using it: what breaks if a step is skipped, what an env var actually controls. No decision rationale (plans / ADRs / commit bodies own that), nothing derivable from the repo tree, no empty "Overview" filler.
- Code comments: English, and only the non-obvious *why* — never narrate what the code plainly says. Exception: linter-mandated doc comments (godoc/dartdoc on exported identifiers) keep the language convention's form and state purpose or usage, in one brief line when the name and signature already say the rest; never implementation, history, or which callers use it. Preconditions and enforced guarantees are usage, not implementation; on security/guard comments R35 governs. Identifiers keep their literal casing everywhere.
- Before committing a new or rewritten spec, README, or doc under `docs/`, run one review pass: `luna` rephrases it, then `opus`, `fable`, and `sol` review the result in sequence, each in a fresh context, following the `skill-tuner` review chain in steps 4 and 5 with the document in place of the skill diff. Use `skill-tuner` for the commands, verdicts, and round limit; code comments are excluded.
