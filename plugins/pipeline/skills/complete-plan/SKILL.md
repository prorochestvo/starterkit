---
name: complete-plan
description: Move a finished plan from plans/ to plans/completed/ with the YYMMDD.NNNN.slug.md naming, after verifying the project's test and lint gates pass. Use when all acceptance criteria of an active plan are met.
argument-hint: <NNN | slug | NNN-slug.md>
---

Move the active plan identified by `$ARGUMENTS` from `plans/` to `plans/completed/`.

Steps:

1. Resolve the source file:
   - `NNN` (3 digits) → the unique `plans/NNN-*.md` matching it.
   - A slug → `plans/*-$ARGUMENTS.md`.
   - A full filename → use directly.
   - Zero or multiple matches → stop and ask the user to disambiguate.
2. **Verify completion gates.** Run the project's test and lint commands as documented in the project's `CLAUDE.md` (e.g. `make test`, `flutter analyze && flutter test`). If `CLAUDE.md` does not document them, ask the user rather than guessing. If anything fails, stop and report — do **not** move the file.
3. **Verify the plan is honest.** Skim the plan's acceptance criteria against what was actually implemented. If implementation diverged, ask the user to update the plan file first, then re-run this skill.
4. Compute the destination filename:
   - `YYMMDD` = today's date in UTC (`date -u +%y%m%d`).
   - `NNNN` = next zero-padded daily index: scan `plans/completed/$YYMMDD.*.md`, take highest existing + 1, else `0001`.
   - `slug` = the slug portion of the source filename (after the `NNN-` prefix).
   - Destination: `plans/completed/$YYMMDD.$NNNN.$slug.md`.
5. Run `git mv <source> <destination>` so history is preserved.
6. Report the move and the new path.

Do not refactor or alter the plan's contents during the move.
