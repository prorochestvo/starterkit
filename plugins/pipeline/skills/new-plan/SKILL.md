---
name: new-plan
description: Create a new plan file in .agents/plans/ as YYMMDD.NNNN.slug.md - named by ~/.claude/bin/plan-name.sh, written from the standard task-breakdown template of the global task-management skill, consuming a backlog entry when the plan comes from one. Use when starting any non-trivial piece of work that needs a plan before implementation.
argument-hint: <title or kebab-case slug> [backlog entry filename]
---

Create a new plan file in `.agents/plans/` for `$ARGUMENTS` (a title or slug, optionally
followed by the backlog entry it comes from).

The rules — tree, naming, template, backlog handover — are the global `task-management`
skill's (`~/.claude/skills/task-management/references/plans.md`); this skill only runs
them in order.

Steps:

0. If a root `plans/` directory exists, stop: the project is not migrated yet, and a plan
   written to `.agents/plans/` would restart the numbering. Run `pipeline:onboard` first
   (`plan-name.sh` refuses to run in that state too).
1. Validate the title: non-empty and describing intent (`add rate limiting`, not `task`).
   If it is empty or meaningless, stop and ask for one.
2. Name the file — never by hand:

   ```sh
   ~/.claude/bin/plan-name.sh -t '<title>'        # from the repo root
   ```

   It prints `YYMMDD.NNNN.slug.md`: today's date and the next free plan number across
   `.agents/plans/`, `completed/`, `history/`, and every legacy shape. That id is fixed for
   the plan's whole life.
3. Write `.agents/plans/<that name>` with the template from
   `~/.claude/skills/task-management/references/plans.md` (section "Creating a plan").
4. If the plan originates from a `.agents/plans/backlog/` entry: move that entry's
   content into the plan, fill the `backlog: <entry filename without .md> (raised <date>)`
   header line — and `origin plan: <id>` when the entry's filename carries a plan-id
   prefix — and **delete the backlog file**: accepted work is tracked as a plan, never in
   both places. Stage the deletion together with the new plan so one commit carries the
   handover.
5. Report the created path, the plan id, and the backlog entry it consumed, if any.

Do not write any production code. This skill only creates the plan file.
