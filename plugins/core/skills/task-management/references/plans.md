# Plans

A plan is the agreed, step-by-step approach to one concern: it states the goal, breaks
the work into tasks with acceptance criteria, and defines verification. Every non-trivial
change starts with one; no source edits before a plan exists.

## The `.agents/` tree

Every project keeps its agent-facing material under one root, `.agents/`:

| Path | Holds |
|---|---|
| `.agents/plans/` | active plans, `YYMMDD.NNNN.slug.md` |
| `.agents/plans/completed/` | shipped plans, moved here unchanged |
| `.agents/plans/history/` | abandoned or superseded plans, moved here unchanged |
| `.agents/plans/backlog/` | open and dropped side-questions — see [backlog.md](backlog.md) |
| `.agents/specs/` | agent-readable specs: contracts, conventions, runbooks an agent follows |
| `.agents/scripts/` | scripts written for or by agents: owner-action handoffs, one-off migrations, probes |
| `.agents/skills/` | project skills; `.claude/skills` is a committed symlink to it |

Human documentation stays in `docs/`; agent instructions stay in `AGENTS.md` at the root,
with `CLAUDE.md` a symlink to it. A project still on a root `plans/` tree is migrated by
`pipeline:onboard` before any new plan or backlog entry lands: while a root `plans/`
exists, do not write to `.agents/plans/` — numbering two trees independently would
collide. `plan-name.sh` refuses to run in that state for the same reason.

One plan per concern. A plan's own Status line and its position in `.agents/plans/` are
both unreliable — verify completion against the code, not the header.

## Naming and the plan id

A plan gets its id at creation and keeps it for life:

```
.agents/plans/YYMMDD.NNNN.slug.md        e.g. 261012.0010.add-rate-limiting.md
```

- `YYMMDD` — the day the plan is created.
- `NNNN` — the plan number: the highest number in use plus one, counted across
  `.agents/plans/`, `completed/`, and `history/` and across every shape on disk (the
  current `YYMMDD.NNNN.slug`, the legacy active `NNN-slug`, the legacy completed
  `YYMMDD.NNNN.slug`). A gap is never refilled; a number is never reused.
- `slug` — kebab-case, describing intent (`add-rate-limiting`, not `task`).

The id `YYMMDD.NNNN` is the string everyone cites — other plans, a `.agents/plans/README.md`
index, decision records, commit bodies, backlog entries raised from the plan — so it is
fixed: completing or abandoning a plan moves the file into `completed/` or `history/`
**without renaming it**, and nothing that points at the id goes stale.

Get the name from the script, never by hand (run from the repo root; `-d` overrides the
plans directory):

```sh
plan-name.sh -t '<title>'
```

## Creating a plan

1. Name the file with `plan-name.sh` as above.
2. Write it with this template:

```markdown
# Task Breakdown

<!-- only when this plan comes from a backlog entry: -->
- backlog: <entry filename without .md> (raised <YYYY-MM-DD>)
<!-- and, when that entry was itself raised from a plan: -->
- origin plan: <YYMMDD.NNNN>

## Overview

<one-paragraph description of the task and its motivation>

## Assumptions

- <assumption>

## Tasks

### Task 1: <Title>
- Description: <what needs to be done>
- Acceptance Criteria:
  - <criterion>
- Pitfalls & edge cases: <list>
- Complexity: Easy | Medium | Hard

## Execution Order

1. Task 1

## Risks

- <risk>

## Trade-offs

- <trade-off>
```

3. If the plan originates from a `.agents/plans/backlog/` entry: move that entry's content
   into the plan, fill the `backlog:` header line (and `origin plan:` when the entry's
   filename carries a plan-id prefix), and **delete the backlog file** — accepted work is
   tracked as a plan, never in both places. Stage the deletion together with the new plan
   so one commit carries the handover. If the entry's assessment returned a `rename_to`,
   that rename is moot once the file is deleted; the plan header cites the entry by the
   name it had when accepted.
4. Report the created path, the plan id, and the backlog entry it consumed, if any.

Creating the plan file writes no production code.

## Content

The plan must be executable without waiting on the owner: take every decision it needs
and record each one with its reasoning and its reversal path. A decision that is the
owner's by nature — scope, preference, business context, money — is asked directly, not
decided in the plan.

## Review and agreement

A plan is reviewed and agreed before implementation. When it is ready and holds no open
implementation questions, it goes through its own review cycle; the reviewers, rounds,
and models are defined by the pipeline (`pipeline:working-agreement`, or the `workflow`
skill where that pipeline is not in force). Findings go back into the plan until it is
approved; a rejected recommendation is recorded in the plan with the reason.

## During execution

Side tasks and nuances that do not block the work go to the backlog — one file each,
prefixed with this plan's id (see [backlog.md](backlog.md)) — and the work moves on.
Decisions taken mid-plan are recorded in the plan with their reasoning and reversal path.

Anything the plan leaves behind — deferred work, findings refuted rather than fixed,
decisions owed to the owner — is written into the plan **before** it is completed, as the
last act of executing it.

## Completing a plan

Complete a plan when all its acceptance criteria are met; in the pipeline this is the end
of the cycle, after the commit and the cleanup of every temporary object (scratch files,
work branches, tags, worktrees). The procedure (`pipeline:complete-plan` runs it):

1. If a root `plans/` directory exists, stop: the project is not migrated yet. Run
   `pipeline:onboard` first.
2. Resolve the source file from what was given — a plan id (`YYMMDD.NNNN`), a bare number
   (`NNNN`, or the legacy `NNN`), a slug, or a full filename — to exactly one file in
   `.agents/plans/`. Zero or multiple matches → stop and ask for disambiguation.
3. **Verify completion gates.** Run the project's test and lint commands as documented in
   its `AGENTS.md`/`CLAUDE.md` (the project gate, e.g. `make verify`, `make test`,
   `flutter analyze && flutter test`). If they are not documented, ask rather than guess.
   If anything fails, stop and report — do **not** move the file.
4. **Verify the plan is honest.** Check the plan's acceptance criteria against what was
   actually implemented. If implementation diverged, ask the owner to update the plan file
   first, then run the procedure again.
5. Move the file **unchanged**: `git mv .agents/plans/<file> .agents/plans/completed/<file>`
   so history is preserved. The id and the slug stay; a legacy active `NNN-slug.md` is
   moved under that same name. If the destination already exists, stop and ask — two
   plans cannot share a number, so a collision means the plan was already completed or
   a number was reused.
6. **Update path links.** The id does not change, so citations by id stay valid. Links
   that include the directory path (`.agents/plans/<file>` in a README index, another
   plan, a decision record) now point at `completed/` — grep the repository for the
   filename and update them, along with anything that still describes the plan as active
   (an index row, another plan's status line). If the project has a check for dangling
   plan references, run it.
7. Report the move and the new path.

Do not refactor or alter the plan's contents during the move.

## Abandoning or superseding a plan

A plan that will not be executed, or that another plan replaces, moves to
`.agents/plans/history/` the same way: `git mv` under its unchanged name, after a line in
the plan records why it was abandoned and, when superseded, the id of the plan that
replaces it. Path links are updated as in step 6 above. The number stays retired — the
next plan still counts it.

## Legacy shapes — never rename history

Repositories carry files from earlier naming rules. They are left exactly as they are;
renaming history to match a new rule breaks the links that already point at it.

- **Active `NNN-slug.md`** (3-digit number, no date). Still a valid active plan. Its
  number counts toward the next `NNNN`. When completed or abandoned it is moved to
  `completed/` or `history/` **under its unchanged name** — no conversion to the
  `YYMMDD.NNNN` shape. A backlog entry raised from it is prefixed with its `NNN`.
- **Completed `YYMMDD.NNNN.slug.md` whose date is the completion day.** Written under the
  rule in force until the id became fixed at creation: `NNNN` is the plan's number and
  counts toward the next one.
- **Completed files from before 2026-08-30.** `NNNN` there is a per-day ordinal unrelated
  to any plan number; several pairs of files across projects share a `YYMMDD.NNNN`
  prefix. They carry no citable id. The per-day counter was replaced because it lost the
  only identifier anyone cites and failed at being an ordinal; a plan number is unique
  per repository by construction and needs no scan.

*What would reverse the fixed id:* a project that numbers plans non-uniquely, or one that
reuses numbers across `.agents/plans/history/`. Neither exists today; the first one to
appear is the argument for revisiting it, and it would need the collision guard in step 5
either way.
