---
name: working-agreement
description: The canonical plan-first pipeline - plan, implement, gate, parallel review, complete - plus the plans/ layout, the project backlog (plans/backlog.md), and the delta form a project's CLAUDE.md keeps instead of restating it. Load before planning, implementing, reviewing, or completing non-trivial work in a repo whose CLAUDE.md carries a "Working agreement" block - writing or reading a plans/NNN-slug.md, recording or triaging a side-question in plans/backlog.md, invoking pipeline:new-plan or pipeline:complete-plan, launching architect / engineer / reviewer / testdoctor agents, running the project gate before review, or deciding how many review lenses to run.
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
4. **Review** — every reviewing agent launched in parallel in ONE message, each
   prompt naming its lens and the changed files. The standard set is four:
   three `reviewer` agents — A: correctness & tests, B: security & operations,
   C: performance & architecture — plus **O: owner standards**, carried by the
   `code-standards-auditor` agent rather than a `reviewer`. **Lens O is standing
   in every fan-out**, on top of whatever lenses a project adds or overrides.
   The full fan-out is mandatory on the first review; the post-fix re-review is
   ONE solo reviewer scoped to the changed lines, plus lens O again if it raised
   anything. Never ask how many reviewers to launch, and never ask whether to
   include lens O.
5. **Complete** — the orchestrator merges the reports, deduplicates, and resolves
   conflicting verdicts, naming what was rejected and why; the user has final
   say. **P0, P1 and P2 loop back to the engineer and are fixed in this pass
   without asking the user**, then re-reviewed. P3 and unverified "worth a look"
   items become tracker issues (or `plans/backlog.md` entries in a repo
   without a tracker), or one batched question at the end — never
   silently dropped, never handed over as an approval request. Only when every
   P0/P1/P2 is fixed or explicitly accepted: move the plan via the
   `pipeline:complete-plan` skill.

## Severity

One scale across every lens, because it decides routing, not tone:

| | | Action |
|---|---|---|
| **P0** | unsafe or broken now — data loss, secret disclosure, a red gate, production breakage | fix now |
| **P1** | violates a standing rule, or breaks under a reachable input | fix now |
| **P2** | a real defect with bounded blast radius | fix now |
| **P3** | a judgement call, a preference, the owner's ruling | issue or batched question |

A lens scopes *what* a reviewer hunts, not severity: any lens may raise any of
P0–P3. Grading a real defect P3 to avoid fixing it is the failure mode to watch
for in yourself.

## Where plans live

Plans live in `plans/` (active), `plans/completed/` (shipped,
`YYMMDD.NNNN.slug.md`), `plans/history/` (abandoned/superseded). One plan per
concern. A plan's own Status line and its position in `plans/` are both
unreliable — verify completion against the code, not the header.

## The backlog — `plans/backlog.md`

Side-questions, ideas, and deferred concerns that surface mid-task are
appended here at the moment they surface — one entry, then back to the task.
The backlog exists so a passing thought neither derails the current work nor
evaporates. Entry form:

```markdown
## <short imperative title>
- raised: <YYYY-MM-DD> — <one-line context: during what work>
- question: <what needs discussing, evaluating, or deciding>
- decision: open
```

Triage happens when the owner asks ("разберём беклог", "triage the backlog")
or when picking work with no instruction: every reviewed entry gets an
explicit decision — `accepted → plans/NNN-slug.md (<date>)` or
`dropped — <one-line reason> (<date>)`. Dropped entries stay in the file:
a drop with a reason can be argued with later; a deletion cannot. Never
delete or resolve an entry silently, and never turn triage into one
question per item — batch it.

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
