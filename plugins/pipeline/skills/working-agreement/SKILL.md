---
name: working-agreement
description: The canonical plan-first pipeline - plan, implement, gate, parallel review, complete - plus the plans/ layout and the delta form a project's CLAUDE.md keeps instead of restating it. Load before planning, implementing, reviewing, or completing non-trivial work in a repo whose CLAUDE.md carries a "Working agreement" block - writing or reading a plans/NNN-slug.md, invoking pipeline:new-plan or pipeline:complete-plan, launching architect / engineer / reviewer / testdoctor agents, running the project gate before review, or deciding how many review lenses to run.
---

# Working agreement

The procedure every non-trivial change runs through, and the contract the four
pipeline agents share. A project's own `CLAUDE.md` restates none of it — it
carries only its delta (gate command, lens override, branching).

## The pipeline

All non-trivial work follows the plan-first pipeline:

1. **Plan** — the `architect` agent writes `plans/NNN-slug.md` (create via the
   `pipeline:new-plan` skill). No source edits before a plan exists. The plan
   must be executable without waiting on the owner: take every decision it
   needs, and record each one with its reasoning and its reversal path.
2. **Implement** — the `engineer` agent executes the plan's tasks with tests.
3. **Gate** — the project's gate command must be green before review; a red tree
   goes to the `testdoctor` agent first, at any stage. Chain gate and commit with
   `&&`, never `;`.
4. **Review** — `reviewer` agents launched in parallel in ONE message, each
   prompt naming its lens and the changed files. The standard is three lenses —
   A: correctness & tests, B: security & operations, C: performance &
   architecture — unless the project declares an override. The full fan-out is
   mandatory on the first review; the post-fix re-review is ONE solo reviewer
   scoped to the changed lines. Never ask how many reviewers to launch.
5. **Complete** — the orchestrator merges the reports, deduplicates, and resolves
   conflicting verdicts, naming what was rejected and why; the user has final
   say. P0/P1 findings loop back to the engineer. Only when every P0/P1 is fixed
   or explicitly accepted: move the plan via the `pipeline:complete-plan` skill.

## Where plans live

Plans live in `plans/` (active), `plans/completed/` (shipped,
`YYMMDD.NNNN.slug.md`), `plans/history/` (abandoned/superseded). One plan per
concern. A plan's own Status line and its position in `plans/` are both
unreliable — verify completion against the code, not the header.

## Lens versus severity

A lens scopes *what* a reviewer hunts, not severity: any lens may raise any of
P0-P3. A review finding backed by a measurement outranks a plan's scope line.

## Project delta form

A project's `CLAUDE.md` does not restate the procedure above. It keeps only the
~4 lines that differ, and points back here:

```markdown
## Working agreement

Plan-first pipeline; the canonical procedure is the `pipeline:working-agreement` skill — load it
before starting non-trivial work. Project delta:

- **Gate:** <the project's exact gate command>
- **Lenses:** standard three  |  OR: override — <letter>: <what it hunts>
- **Branching:** standard (`type/<issue>-<slug>`, PR into `main`)  |  OR: <the project's model>
```
