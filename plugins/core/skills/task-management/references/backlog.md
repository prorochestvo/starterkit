# The backlog — `.agents/plans/backlog/`

Side-questions, ideas, and deferred concerns that surface mid-task are captured the
moment they surface — one file, then back to the task. The backlog exists so a passing
thought neither derails the current work nor evaporates. It is a tracker, not an archive:
the top level holds exactly the open questions; closed ones — dropped, or already done
without a plan — live in `backlog/history/`, and anything accepted is visible as a plan.

"What is in the backlog" is answered from `backlog-triage.sh --list` — one
line per open entry, name and title — without opening the files. Open an entry only to
work on or triage it; never read `history/` unless asked.

## The gate, before an entry is written

A draft entry is written only when the gate says it is needed. Write the draft to a
temporary file and run, in the background, so the task goes on:

```sh
backlog-triage.sh --gate -f <draft file>
```

`sol` and `opus` judge in parallel whether the entry is needed and whether an open entry
already covers it; when they disagree, or one does not answer, `fable` decides having seen
both votes. The answer is `create`, `duplicate_of`, `reason`, and `decided_by`:

- `create: true` → name it (below) and write it.
- `create: false` → do not write it; say so in the end-of-task report with the reason,
  and with the open entry it duplicates if there is one.
- `decided_by: none` → no model answered; write the entry. An outage must never swallow
  a question.

## Capture

One question per file. The name carries the date raised, a **provisional priority**, and
the next free index across the directory, `history/` included:

```
.agents/plans/backlog/YYMMDD.P.NNNN.slug.md          e.g. 260920.H.0012.usage-cache-is-shared.md
```

`P` is `H`, `M`, or `L`:

- `H` — correctness, security, data loss, or something already breaking;
- `M` — a real defect or gap that is not urgent;
- `L` — cleanup, consistency, nice-to-have.

`NNNN` is the highest index present plus one; indexes are never reused — the gap an
accepted (deleted) entry leaves is never refilled — and they count across both this
shape and the older `YYMMDD.NNNN` one, so an existing backlog keeps its numbering.

**Origin plan prefix.** An entry that came out of a plan — raised while working on that
plan, or a review finding deferred out of that plan's cycle — is prefixed with the plan's
id:

```
<plan id>-YYMMDD.P.NNNN.slug.md     e.g. 261012.0010-261012.H.0017.cache-is-shared.md
                                     legacy active plan: 007-261012.L.0017.q.md
```

An entry with no origin plan has no prefix. The prefix survives a priority rename after
assessment.

Get the name from the script, never by hand (run from the repo root; the script picks the
backlog directory, `-d` overrides it; `-P` takes the origin plan's id or its filename):

```sh
backlog-triage.sh --name -t '<title>' -p H|M|L [-P <plan id or plan file>]
```

**The priority at capture is yours to set, not a model's.** The gate decides only whether
the entry exists; judge the priority yourself and move on. It is provisional and gets
checked before the entry becomes work.

File form:

```markdown
# <short imperative title>

- raised: <YYYY-MM-DD> — <one-line context: during what work>
- decision: open

<The question: what needs discussing, evaluating, or deciding, with
whatever context a cold reader needs to judge it.>
```

## Review findings

A review finding that does not block the implementation lands here too, at any review
phase — the cycle does not stall on it, and nothing is silently dropped. Its severity goes
on the `raised:` line and maps onto the filename's priority: P0/P1 → `H`, P2 → `M`,
P3 → `L`. It is prefixed with the id of the plan whose cycle deferred it.

## Triage

Triage happens when the owner asks ("разберём беклог", "triage the backlog") or when
picking work with no instruction: every reviewed file gets an explicit decision on its
`decision:` line — `accepted` or `dropped — <one-line reason> (<date>)`. Never resolve an
entry silently, and never turn triage into one question per item — batch it. Grooming
(below) is a separate pass: it closes stale entries and leaves the rest `open`.

## Grooming

"Груминг беклога" ("groom the backlog") means: check every open entry for relevance and
close the stale ones. **Decide each entry yourself, ask the owner nothing, accept nothing,
and report at the end** — an entry that should become work stays open and is named in the
report. Honour a batch size or a pause the owner sets; otherwise run to the end.

1. Work on a new branch `chore/backlog-grooming` from the tip of the integration branch, in
   its own worktree (the `workflow` preflight rule). Build the entry list from
   `backlog-triage.sh --list` when the pass starts; before step 7, merge the integration
   branch into `chore/backlog-grooming` and handle the entries it added as one extra batch.
2. One agent, one entry at a time. Run each gate as its own foreground command with a
   600-second timeout, not in the background as at capture, and apply its answer before
   the next entry; a loop of gates outlives the command timeout and loses that order.
3. For each entry:
   - already settled — resolved in the code, by a merged commit, or by a later plan or
     decision, checked against the code and `git log` → close it as `done` or `dropped`
     (see the endings);
   - otherwise gate it and, unless the gate is weak (step 4), apply the answer:

     ```sh
     backlog-triage.sh --gate -f .agents/plans/backlog/<entry>.md
     ```

     `create: true` keeps it open with its `decision:` line unchanged; `create: false`
     drops it with the gate's reason. With a `duplicate_of`, it is dropped naming that
     entry only when it is a different entry open at the top level, otherwise it stays open
     as a weak gate; a useful detail of the dropped entry goes into the open one as a dated
     note. When unsure, keep.
4. A weak gate keeps the entry open and is named in the report: `votes.sol` or
   `votes.opus` is null, `votes.fable` is null after a sol/opus split, a vote's `reason`
   starts with `self-duplicate vote ignored`, or `duplicate_of` names an entry that is not
   open at the top level. Two weak gates in a row from a reviewer outage (usage limits, a
   failing call): stop, commit, and finish with step 7, naming the entry where the pass
   stopped.
5. **Never re-gate an entry from `history/`**: the reviewers read the repository, find the
   recorded decision and the commit that made it, and repeat it. A closed entry is
   reopened only on new evidence or the owner's word.
6. Commit every 10–20 entries, staging only `.agents/plans/backlog`; commit messages
   follow the `cli-git` commits rule.
7. At the end, squash-merge the branch into the integration branch under the project's
   branch rules, push, and delete the branch and the worktree. Report the kept / done /
   dropped counts, one line per closed entry with its reason, the weak gates, and any drop
   the owner may want to reverse — for example one closed on a plan's decision, not a gate.

## Assessment, before an entry becomes work

**An entry is assessed by a model outside this family before it is accepted**, never at
capture. This is the moment the answer changes something, and by then the file carries
the context a cold judgement needs:

```sh
backlog-triage.sh --assess -f .agents/plans/backlog/<entry>.md
```

It returns `worth`, a `priority`, a `reason`, and `rename_to` when the priority moved.
Apply it:

- `worth: false` → the entry is **dropped with the returned reason** (see the endings),
  not deleted. A rejected entry never becomes work, so its priority stops mattering.
- `worth: true` → adopt the returned priority. The entry is accepted and deleted in the
  commit that creates the plan, so `rename_to` needs no `git mv`: the plan header cites
  the entry by its name at acceptance and records the adopted priority. Rename only an
  entry that stays open, keeping the index and the origin prefix.
- `assessed_by: none` → no reviewer answered. **Proceed anyway** at the existing priority
  and say so. An outage must never park a question indefinitely.

The cheap lane answers by default because "is this real, and how urgent" is
classification with a checkable answer; the paid clients are called only when it reports
`H` or when nothing answered. A disagreement on urgency resolves **upward** —
under-rating a real defect costs more than looking at an `M` that turned out to be an `L`.

*Reversing this:* drop the `--assess` call and accept entries on the priority set at
capture. Priority is judged here rather than at the gate because by now the file carries
the context a cold judgement needs; the gate, run in the background, only filters what
should not exist. Dropping the gate: skip `--gate` and write every draft.

## The two endings

The two decisions end differently:

- **accepted** — the entry **leaves `.agents/plans/backlog/` the moment the work starts**,
  not when it finishes. Its content moves into the plan that now owns it (named by
  `plan-name.sh`, see [plans.md](plans.md)), the plan records
  `backlog: <entry filename without .md> (raised <date>)` under its header — and
  `origin plan: <id>` when the entry carried a plan-id prefix — and the backlog file is
  deleted in the same commit that adds the plan. From there it follows the ordinary plan
  lifecycle and ends in `.agents/plans/completed/` — an accepted entry is never tracked
  in two places at once.
- **dropped** — `decision: dropped — <reason> (<date>)`; the file keeps its name and
  moves with `git mv` to `.agents/plans/backlog/history/`, out of the open list: a drop
  with a reason can be argued with later, a deletion cannot.
- **done** — the question was settled by work outside a plan:
  `decision: done — <commit, PR, or plan that settled it> (<date>)`, then the same
  `git mv` to `history/`.

Reopening a closed entry is a `git mv` back with `decision: open`.

The deleted entries are recoverable from git history through the plan's `backlog:` line.
