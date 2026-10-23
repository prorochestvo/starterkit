# Standards extraction

A generalizable code requirement or working pattern from my feedback or a review — not a
one-off for this repo — becomes a numbered `R#` rule. Rules have two homes: the
`common-contracts` skill (pick the reference by task, component type, and language) and,
for rules about proving that a check or a change did what it claims,
`workflow/references/verification.md`. Draft a new rule as `R?`; number it only in the
change that merges it into `common-contracts` or `verification.md` — the next number after
the highest in the `code-standards-auditor` agent's table, re-read at merge — and replace
every `R?` in that change. Whenever I
correct something, state a preference, or confirm an approach as standard, route it by
scope: the owner's global `AGENTS.md` (draft only — the owner applies it), a
`common-contracts` or `verification.md` rule, a plugin or project skill, the project's
`AGENTS.md`, or agent memory for a machine-only fact. Never delete an existing rule
without my say-so.
