---
name: working-agreement
description: The canonical plan-first pipeline - plan with its own review cycle (parallel reviewers, then gemini/codex), implement, gate, staged review (parallel reviewers, standards audit, external reviewers), one-commit completion with cleanup - plus per-role model/effort assignments, collective blocking decisions, and the delta form a project's CLAUDE.md keeps instead of restating it. Load before planning, implementing, reviewing, or completing non-trivial work in a repo whose CLAUDE.md carries a "Working agreement" block - writing or reading a .agents/plans/YYMMDD.NNNN.slug.md, recording or triaging a side-question in .agents/plans/backlog/ (the plan and backlog rules themselves live in the task-management skill), invoking pipeline:new-plan or pipeline:complete-plan, launching architect / engineer / reviewer / testdoctor agents, running the project gate before review, or deciding how many parallel reviewers to run.
---

# Working agreement

The procedure every non-trivial change runs through, and the contract the four
pipeline agents share. A project's own `CLAUDE.md` restates none of it — it
carries only its delta (gate command, focus override, branching).

The skills this agreement and the pipeline agents name by their bare name
(`task-management`, `workflow`, `cli-git`, `ai-gemini`, `ai-codex`, ...) and the
commands they call (`plan-name.sh`, `model-id`, `second-opinion.sh`,
`codex-limits.py`, ...) come from the `core` plugin, which `pipeline` depends on:
plugin users find these skills as `core:<name>`, and the commands on the Bash
tool's `PATH`. When they are missing, install core@starterkit.

## The pipeline

1. **Plan** — the `architect` agent (opus, medium effort) writes
   `.agents/plans/YYMMDD.NNNN.slug.md` (create via the `pipeline:new-plan` skill). No source
   edits before a plan exists. The plan must be executable without waiting on
   the owner: take every decision it needs, and record each one with its
   reasoning and its reversal path. When the plan is ready and holds no open
   implementation questions, the plan itself is reviewed, in two rounds:
   - **Claude plan review** — 2-3 parallel `reviewer` agents (opus, medium),
     one focus each, over the plan; findings go back to the architect and the
     cycle repeats until the plan is approved.
   - **External plan review** — one general external review from gemini
     (`g-pro`, high effort) via the `ai-gemini` skill. Fold its
     recommendations in, or record in the plan why one was rejected.
2. **Code** — the `engineer` agent (haiku, medium effort) executes the
   plan's tasks with tests: Codex (`luna`, medium reasoning) writes the
   code, the engineer verifies and gates it. When Codex cannot run (quota,
   auth, or no binary) the engineer writes the code itself. Side tasks and nuances that do not block the work
   go to `.agents/plans/backlog/` — one file each — and the cycle moves on. A genuine
   blocker is resolved collectively (see **Blocking decisions**), not by
   stopping for the owner. The project's gate must be green before review; a
   red tree goes to the `testdoctor` agent first, at any stage. Chain gate
   and commit with `&&`, never `;`.
3. **Review** — three phases, in order:
   - **Parallel reviewers** — `reviewer` agents (opus, medium) launched in
     parallel in ONE message, each prompt naming its focus and the changed
     files (standard: correctness and tests, security and operations,
     architecture and performance). **P0 findings are fixed immediately,
     without asking**, then re-checked by one solo reviewer scoped to the
     changed lines.
   - **Standards audit** — once the parallel reviewers are clean, the
     `core:code-standards-auditor` agent checks the change against the owner's R#
     rule set as its own sequential pass and its grooming is applied directly:
     the goal is code that reads as if the owner wrote it. The owner keeps
     growing that rule set; never skip this audit and never ask whether to run
     it.
   - **External review, only when something blocks.** A finding that would
     block is not settled inside one model family: state your own position,
     then run the owner's wrapper, which assembles the material and merges the
     outside verdicts into one ranked report.

     ```sh
     second-opinion.sh --target branch --question '<the finding>'
     ```

     `--target` also takes `working`, `staged`, `commit:REF`, `files:A,B,C`;
     `--help` carries the rest. It drives `agy` (the Gemini client - there is no
     `gemini` binary on these machines) and optionally OpenRouter. **No blocker,
     no external call**: a cycle with nothing to escalate must not spend a paid
     quota.
     Agreement settles it and the cycle continues; only a failed consensus
     reaches the owner, with each position stated.
   At any phase, a finding that does not block the implementation goes to
   `.agents/plans/backlog/` with its severity recorded — the cycle does not stall on
   it, and nothing is silently dropped.
4. **Commit** — the cycle ends in a commit: one commit per plan and linear
   history is the canonical shape — depart from it only when atomicity
   genuinely demands a split. Then remove every temporary object the task
   created — scratch files, work branches, tags, worktrees — and move the
   plan via the `pipeline:complete-plan` skill.

## Background execution & context hygiene

Pipeline work never occupies the foreground. Every stage — architect,
engineer, parallel reviewers, standards audit, external reviewers — is
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
| architect / plan review | opus + medium | `g-pro` + high | — |
| engineer | haiku + medium (drives Codex; writes only as last fallback) | — | `luna` + medium (writes the code) |
| reviewer | opus + medium | `g-pro` + high | `luna` |
| testdoctor | opus + medium | — | — |

Medium is the default effort for every Claude role: the owner's call on
2026-10-04, trading depth per call for headroom across the whole cycle. Raise
one role in its agent frontmatter when a project needs it.
(`g-pro` offers only low/high effort — verified against the agy
catalog; high is the review tier. Test diagnosis is judgment work, hence
testdoctor rides the reviewer tier.)

**A role's model is fixed; never downgrade it on your own.** A stage that
stalls or times out is retried on the same model with a tighter brief:
write the output file's skeleton first, read in ranges, save after each
section, scope the question. If a cheaper model still looks necessary, that
is the owner's call, asked explicitly — not a `model:` override mentioned in
passing. The engineer's fallback is the one exception, and it is not a choice
made on the fly: haiku writes only when Codex cannot run.

The two external reviewers sit at deliberately different tiers because their
plans behave differently. Gemini runs at its top tier: measured over the
week to 2026-09-13 the Pro plan stood at 1% of its weekly allowance, so the
cheap tier was bought with quality for a constraint that does not exist.
Codex stays at its cheapest tier, and since 2026-10-04 it also writes the
code, so implementation spends the same weekly allowance as the external
review. When that allowance runs out, haiku writes the code. Check the
plan with `codex-limits.py`. The
week of 2026-09-13 showed the allowance exhausted on day one, a reading
possibly polluted by free-tier usage; as of 2026-10-04 the weekly window
stood at 2% used.

Gemini and codex are reached through the `ai-gemini` and `ai-codex` skills
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

One scale across every reviewer, because it decides routing, not tone:

| | | Action |
|---|---|---|
| **P0** | unsafe or broken now — data loss, secret disclosure, a red gate, production breakage | fix now, never ask |
| **P1** | violates a standing rule, or breaks under a reachable input | backlog; if it genuinely blocks, route via Blocking decisions |
| **P2** | a real defect with bounded blast radius | backlog |
| **P3** | a judgement call, a preference, the owner's ruling | backlog |

A focus scopes *what* a reviewer hunts, not severity: any reviewer may raise
any of P0-P3. Grading a real P0 down to avoid fixing it is the failure mode
to watch for in yourself. The standards audit is the exception to the backlog
default: its grooming is applied in-cycle — that is its purpose.

## Plans and the backlog

Every project keeps its agent-facing material under one root, `.agents/`:
`plans/` (active plans), `plans/completed/` (shipped), `plans/history/`
(abandoned or superseded), `plans/backlog/` (open and dropped side-questions),
`specs/` (agent-readable contracts, conventions, runbooks), `scripts/` (scripts
written for or by agents), and `skills/` (project skills; `.claude/skills` is a
committed symlink to it). Human documentation stays in `docs/`; agent
instructions stay in `AGENTS.md` at the root, with `CLAUDE.md` a symlink to it.
A project still on a root `plans/` tree is migrated by `pipeline:onboard`.

The rules for plans and the backlog — the tree, the naming
(`YYMMDD.NNNN.slug.md` for plans, `YYMMDD.P.NNNN.slug.md` for backlog entries,
prefixed with the origin plan's id), the plan template, review before
implementation, capture, triage, assessment, completion, and the legacy shapes —
live in ONE place: the `task-management` skill (references `plans.md` and
`backlog.md`).
Load it for any of those; this skill does not restate them. In short: one plan
per concern; verify completion against the code, not the plan's header; capture
a side-question instantly as one backlog file (prefixed with the active plan's
id) and get back to the task; a deferred review finding lands there with its
severity (P0/P1 → H, P2 → M, P3 → L); never resolve a backlog entry silently.

## Project delta form

This skill is the ONLY place the pipeline is described. A project's
`CLAUDE.md` never restates it — no step lists, no agent names, no focus
definitions, no severity tables, no .agents/plans/ layout. Any such restatement is
drift from an older edition: replace it with the form below on sight, and
keep the heading exactly `## Working agreement`.

```markdown
## Working agreement

Plan-first pipeline; the canonical procedure is the `pipeline:working-agreement` skill — load it
before starting non-trivial work. Project delta:

- **Gate:** <the project's exact gate command>
- **Review focus:** standard staged set — see `pipeline:working-agreement`.  |  OR:
  override / escalation — <focus name>: <what it hunts>
- **Branching:** standard — `dev` is the integration branch  |  OR: <the project's model>
```

What belongs in the bullets — and only this — is the project's genuine
delta: the exact gate command with its project-true caveats (extra CI-only
steps, path quirks), focus overrides or escalation sets beyond the standard
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
