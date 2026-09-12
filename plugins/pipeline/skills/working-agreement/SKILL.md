---
name: working-agreement
description: The canonical plan-first pipeline - plan with its own review cycle (Claude lenses, then gemini/codex), implement, gate, staged review (Claude fan, author-standards pass, external single-lens reviews), one-commit completion with cleanup - plus the plans/ layout, the project backlog (plans/backlog/), per-role model/effort assignments, collective blocking decisions, and the delta form a project's CLAUDE.md keeps instead of restating it. Load before planning, implementing, reviewing, or completing non-trivial work in a repo whose CLAUDE.md carries a "Working agreement" block - writing or reading a plans/NNN-slug.md, recording or triaging a side-question in plans/backlog/, invoking pipeline:new-plan or pipeline:complete-plan, launching architect / engineer / reviewer / testdoctor agents, running the project gate before review, or deciding how many review lenses to run.
---

# Working agreement

The procedure every non-trivial change runs through, and the contract the four
pipeline agents share. A project's own `CLAUDE.md` restates none of it — it
carries only its delta (gate command, lens override, branching).

## The pipeline

1. **Plan** — the `architect` agent (opus, high effort) writes
   `plans/NNN-slug.md` (create via the `pipeline:new-plan` skill). No source
   edits before a plan exists. The plan must be executable without waiting on
   the owner: take every decision it needs, and record each one with its
   reasoning and its reversal path. When the plan is ready and holds no open
   implementation questions, the plan itself is reviewed, in two rounds:
   - **Claude plan review** — 2-3 `reviewer` lenses (opus, high) over the
     plan; findings go back to the architect and the cycle repeats until the
     plan is approved.
   - **External plan review** — one general lens from gemini
     (`gemini-3.8-flash`, low effort) via the `gemini` skill. Fold its
     recommendations in, or record in the plan why one was rejected.
2. **Code** — the `engineer` agent (sonnet, medium effort) executes the
   plan's tasks with tests. Side tasks and nuances that do not block the work
   go to `plans/backlog/` — one file each — and the cycle moves on. A genuine
   blocker is resolved collectively (see **Blocking decisions**), not by
   stopping for the owner. The project's gate must be green before review; a
   red tree goes to the `testdoctor` agent first, at any stage. Chain gate
   and commit with `&&`, never `;`.
3. **Review** — three phases, in order:
   - **Claude fan** — `reviewer` agents (opus, high) launched in parallel in
     ONE message, each prompt naming its lens and the changed files
     (standard: A correctness & tests, B security & operations,
     C performance & architecture). **P0 findings are fixed immediately,
     without asking**, then re-checked by one solo reviewer scoped to the
     changed lines.
   - **Author-standards pass** — once the fan is clean, the
     `code-standards-auditor` agent (lens O, the owner's R# rule set) runs as
     its own sequential pass and its grooming is applied directly: the goal
     is code that reads as if the owner wrote it. The owner keeps growing
     that rule set; never skip this pass and never ask whether to run it.
   - **External single-lens reviews** — codex (`gpt-5.6-luna`) and gemini
     (`gemini-3.1-pro`, high effort), one lens each over the final diff.
   At any phase, a finding that does not block the implementation goes to
   `plans/backlog/` with its severity recorded — the cycle does not stall on
   it, and nothing is silently dropped.
4. **Commit** — the cycle ends in a commit: one commit per plan and linear
   history is the canonical shape — depart from it only when atomicity
   genuinely demands a split. Then remove every temporary object the task
   created — scratch files, work branches, tags, worktrees — and move the
   plan via the `pipeline:complete-plan` skill.

## Background execution & context hygiene

Pipeline work never occupies the foreground. Every stage — architect,
engineer, reviewer fan, author-standards pass, external reviews — is
launched as background subagents, and the main thread stays free to talk to
the owner and accept new commands while stages run. Do not block the
conversation waiting on a stage: report stage completions as they land, and
interleave new owner requests with the running pipeline.

Context hygiene: auto-compact triggers at 50% of the context window
(`autoCompactWindow` in the global settings). Past that line, start no new
stage: finish the active tasks and compact as soon as all of them are done —
never mid-stage. The precompact handoff (deterministic harvest plus model
synthesis) carries the hard state across, and background subagents live in
their own contexts, so a main-thread compaction never kills them.

## Models and effort

| Role | Claude | Gemini | Codex |
|---|---|---|---|
| architect / plan review | opus + high | `gemini-3.8-flash` + low | — |
| engineer | sonnet + medium | — | — |
| reviewer | opus + high | `gemini-3.1-pro` + high | `gpt-5.6-luna` |
| testdoctor | opus + high | — | — |

(`gemini-3.1-pro` offers only low/high effort — verified against the agy
catalog; high is the review tier. Test diagnosis is judgment work, hence
testdoctor rides the reviewer tier.)

Gemini and codex are reached through the `gemini` and `codex` skills
(headless CLIs). They see nothing of the session: every call carries
self-contained context and a concrete question.

## Blocking decisions

A blocker is not an automatic question to the owner. State the options, ask
gemini and codex (their reviewer tiers), and weigh the three positions:

- **Consensus** → take the decision, record the choice, the reasoning, and
  the reversal path in the plan, and keep moving.
- **No consensus** → ONE batched question to the owner, recommendation first.

A question that is the owner's by nature — scope, preference, business
context, money — is not a blocking implementation decision at all: no
quorum can answer it, so it goes to the owner directly.

## Severity

One scale across every lens, because it decides routing, not tone:

| | | Action |
|---|---|---|
| **P0** | unsafe or broken now — data loss, secret disclosure, a red gate, production breakage | fix now, never ask |
| **P1** | violates a standing rule, or breaks under a reachable input | backlog; if it genuinely blocks, route via Blocking decisions |
| **P2** | a real defect with bounded blast radius | backlog |
| **P3** | a judgement call, a preference, the owner's ruling | backlog |

A lens scopes *what* a reviewer hunts, not severity: any lens may raise any
of P0-P3. Grading a real P0 down to avoid fixing it is the failure mode to
watch for in yourself. The author-standards pass is the exception to the
backlog default: its grooming is applied in-cycle — that is its purpose.

## Where plans live

Plans live in `plans/` (active), `plans/completed/` (shipped,
`YYMMDD.NNNN.slug.md`), `plans/history/` (abandoned/superseded). One plan per
concern. A plan's own Status line and its position in `plans/` are both
unreliable — verify completion against the code, not the header.

## The backlog — `plans/backlog/`

Side-questions, ideas, and deferred concerns that surface mid-task are
captured the moment they surface — one file, then back to the task. The
backlog exists so a passing thought neither derails the current work nor
evaporates.

One question per file, named like completed plans — date raised plus the
next free index across the directory: `plans/backlog/YYMMDD.NNNN.slug.md`
(indexes are never reused, dropped files keep theirs). File form:

```markdown
# <short imperative title>

- raised: <YYYY-MM-DD> — <one-line context: during what work>
- decision: open

<The question: what needs discussing, evaluating, or deciding, with
whatever context a cold reader needs to judge it.>
```

Review findings deferred out of a cycle land here too, with their severity
on the `raised:` line.

Triage happens when the owner asks ("разберём беклог", "triage the backlog")
or when picking work with no instruction: every reviewed file gets an
explicit decision on its `decision:` line — `accepted` or `dropped —
<one-line reason> (<date>)`. Never resolve an entry silently, and never turn
triage into one question per item — batch it.

The backlog is a tracker, not an archive, so the two decisions end
differently:

- **accepted** — the entry **leaves `plans/backlog/` the moment the work
  starts**, not when it finishes. Its content moves into the plan that now
  owns it, the plan records `backlog: YYMMDD.NNNN.slug (raised <date>)` under
  its header, and the backlog file is deleted in the same commit that adds
  the plan. From there it follows the ordinary plan lifecycle and ends in
  `plans/completed/` — an accepted entry is never tracked in two places at
  once.
- **dropped** — the file stays in place with its reason: a drop with a reason
  can be argued with later, a deletion cannot.

So `plans/backlog/` holds exactly the open questions plus the dropped ones;
anything accepted is visible as a plan, active or completed. The deleted
entries are recoverable from git history through the plan's `backlog:` line.

## Project delta form

This skill is the ONLY place the pipeline is described. A project's
`CLAUDE.md` never restates it — no step lists, no agent names, no lens
definitions, no severity tables, no plans/ layout. Any such restatement is
drift from an older edition: replace it with the form below on sight, and
keep the heading exactly `## Working agreement`.

```markdown
## Working agreement

Plan-first pipeline; the canonical procedure is the `pipeline:working-agreement` skill — load it
before starting non-trivial work. Project delta:

- **Gate:** <the project's exact gate command>
- **Lenses:** standard staged set — see `pipeline:working-agreement`.  |  OR:
  override / escalation — <letter>: <what it hunts>
- **Branching:** standard — `dev` is the integration branch  |  OR: <the project's model>
```

What belongs in the bullets — and only this — is the project's genuine
delta: the exact gate command with its project-true caveats (extra CI-only
steps, path quirks), lens overrides or escalation sets beyond the standard
staged set, and the branching model with its consequences (integration
branch, `--base` flags, issues that need manual closing). A bullet may carry
a caveat sentence; it may not re-explain what this skill already says. When
the delta is standard on all three axes, the block is still kept — it is
the marker that the repo runs the pipeline at all.

## Branching, the standard model

`dev` is the integration branch: merge into it, collect commits on it, and
cut `dev`/`alpha` tags from it without asking the owner. Beyond that there
are no branch ceremonies — keep history linear (it reads better), and land
one commit per task/plan. Release lines, protected branches, and anything
outward-facing follow the global commit rules, not this section.
