---
name: complete-plan
description: Move a finished plan from .agents/plans/ to .agents/plans/completed/ under its unchanged YYMMDD.NNNN.slug.md name (git mv, no rename), after verifying the project's test and lint gates pass and the plan matches what was built. Use when all acceptance criteria of an active plan are met.
argument-hint: <YYMMDD.NNNN | NNNN | slug | filename>
---

Move the active plan identified by `$ARGUMENTS` from `.agents/plans/` to
`.agents/plans/completed/`.

The rules — gates, the fixed plan id, legacy shapes — are the `task-management`
skill's (its reference `plans.md`, section "Completing a plan"); this skill only runs
them in order. If the `task-management` skill cannot be loaded, stop and report:
install core@starterkit.

Steps:

0. If a root `plans/` directory exists, stop: the project is not migrated yet. Run
   `pipeline:onboard` first.
1. Resolve the source file to exactly one file in `.agents/plans/`:
   - a plan id `YYMMDD.NNNN` → `.agents/plans/YYMMDD.NNNN.*.md`;
   - a bare number `NNNN` (or legacy `NNN`) → the unique file carrying that number
     (`*.NNNN.*.md` or the legacy `NNN-*.md`);
   - a slug → `.agents/plans/*.<slug>.md` or the legacy `.agents/plans/*-<slug>.md`;
   - a full filename → use directly.
   Zero or multiple matches → stop and ask the user to disambiguate.
2. **Verify completion gates.** Run the project's test and lint commands as documented in
   the project's `AGENTS.md`/`CLAUDE.md` (e.g. `make verify`, `make test`,
   `flutter analyze && flutter test`). If they are not documented, ask the user rather
   than guessing. If anything fails, stop and report — do **not** move the file.
3. **Verify the plan is honest.** Skim the plan's acceptance criteria against what was
   actually implemented. If implementation diverged, ask the user to update the plan
   file first, then re-run this skill.
4. Move the file **unchanged** — the id `YYMMDD.NNNN` is fixed for life, and a legacy
   `NNN-slug.md` keeps that name too:

   ```sh
   git mv .agents/plans/<file> .agents/plans/completed/<file>
   ```

   If the destination already exists, stop and ask: two plans cannot share a number, so
   a collision means the plan was already completed or a number was reused.
5. **Update path links.** Citations by id stay valid. Links that include the directory
   path (`.agents/plans/<file>` in a `.agents/plans/README.md` index, another plan, a
   decision record) now point at `completed/`: grep the repository for the filename and
   update them, along with anything that still describes the plan as active. If the project has a check for dangling plan references, run it.
6. Report the move and the new path.

Do not refactor or alter the plan's contents during the move. Anything the plan leaves
behind — deferred work, findings refuted rather than fixed, decisions owed to the owner —
is written into the plan **before** this skill runs, as the last act of executing it.
