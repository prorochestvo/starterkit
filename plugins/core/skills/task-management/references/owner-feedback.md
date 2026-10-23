# Owner feedback

Owner feedback is an owner-authored `owner-feedback-YYYYMMDD.md` (or `.txt`) file in
`.agents/plans/`. Files named in the earlier `review-YYYYMMDD.md`/`.txt` shape are owner
feedback too and keep their names. It is one indivisible, mandatory task, regardless of
how many findings, questions, or requested changes it contains. Unlike a plan,
it is not generated or named by an agent.

## Authority and immutability

- Treat every item as required. Do not reject, omit, downgrade, close as
  "not applicable", defer to backlog, or silently substitute another task.
- The source file is owner-controlled: never edit its content, format, name,
  or extension, including adding checkboxes, status markers, or notes.
- Clarify ambiguous instructions, discuss implementation details, and suggest
  alternatives with the owner. Only an explicit owner decision can change the
  obligation to satisfy an item; record that decision outside the source file.
- Do not apply backlog `--gate` or `--assess`, plan naming scripts, or plan
  abandonment/supersession procedures to owner feedback files.

## Scheduling gate

- Before starting any **new** task, check for unfinished owner feedback files in
  `.agents/plans/` matching `owner-feedback-YYYYMMDD.*` or the earlier `review-YYYYMMDD.*`.
- While any such review remains open, do not start other new tasks, regardless
  of their priority. Completing the owner feedback takes precedence.
- Work already in progress when the review was opened may continue; do not
  interpret this exception as permission to start additional tasks.
- The owner may explicitly authorize a specific new task despite this gate.
  That exception applies only to the authorized task and does not lift the gate
  for other work.
- If multiple owner feedback files are open, all remain mandatory. Ask the owner to
  resolve conflicting instructions or execution order rather than dropping one.

## Execution and progress

- Read the entire review and account for every item, including questions and
  conditional requests. Treat the file as a single task, not a menu of tasks.
- Use the applicable `workflow` checks and normal project permissions during
  implementation. Discuss genuine blockers; do not mark an unresolved item done.
- Track progress and owner decisions in an independent working note or task
  report if needed, never in the review source file.
- A discussion, a proposed alternative, or a backlog entry is not completion.
  Verify the result of each item against the owner's instruction or explicit
  resolution.

## Skill improvement handoff

- Every owner feedback file is also an explicit batch of owner feedback about code, architecture, agent behavior, instructions, or skills. No `~WTF`, `~OK`, area tag, or special header is required to trigger this handoff.
- **First resolve and verify every review item in the project. Then** process all items through the existing `skill-tuner` procedure, before closing the review. Do not tune skills as a substitute for fixing the code.
- Treat each distinct remark as input for triage, not as an automatic rule. Do not assume a programming language: a review may concern Go, PHP, Scala, Dart, multiple languages, or no code at all. `skill-tuner` determines the appropriate existing language- or stack-specific skill or contract, shared engineering skill, agent workflow, project-specific instruction, or one-off correction (`none`/`external`). Prefer the narrowest applicable scope; do not turn project-specific details into global rules.
- Apply only changes permitted by `skill-tuner` and the global instructions. Respect its review chain, draft-only targets, approval requirements, and logging. The review's mandatory completion does not override those restrictions or force every remark to produce a skill edit.
- Track each remark's tuning disposition outside the immutable review file. A `none`, `external`, `rejected`, `drafted`, or `queued` outcome counts as processed only when recorded according to `skill-tuner`; it does not authorize skipping the underlying review item. If the tuner cannot complete its required procedure, keep the review open unless the owner explicitly resolves the blocker.

## Completion

- Only after **every** item is resolved, applicable verification passes, and every remark has been processed through `skill-tuner`,
  move the original file unchanged to `.agents/plans/completed/` using `git mv`.
  Keep the exact filename and extension. Do not edit or regenerate it.
- If the destination already exists, stop and ask; do not overwrite or rename.
- Update any references to its former path outside the review file, and report
  the completed items and final path.
- An incomplete or blocked review stays in `.agents/plans/`; it cannot be
  abandoned or superseded through the ordinary plan lifecycle.
