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
   - `NNNN` = **the plan's own number**, zero-padded to four digits — `007-foo.md` → `0007`. A plan whose source filename carries no number takes `0000`.
   - `slug` = the slug portion of the source filename (after the `NNN-` prefix).
   - Destination: `plans/completed/$YYMMDD.$NNNN.$slug.md`.
   - **If that path already exists, stop and ask.** Two plans cannot share a number, so a collision means the source was already completed under another name, or a number was reused.
5. Run `git mv <source> <destination>` so history is preserved.
6. **Re-point the citations.** A plan is cited by number — from other plans, from a `plans/README.md` index, from decision records, from commit bodies. Grep the repository for the number and update anything that describes it as active. If the project has a check for dangling plan references, run it.
7. Report the move and the new path.

Do not refactor or alter the plan's contents during the move. Anything the plan
leaves behind — deferred work, findings refuted rather than fixed, decisions
owed to the owner — is written into the plan **before** this skill runs, as the
last act of executing it.

## Why `NNNN` is the plan number

It was a per-day counter until 2026-08-30, and repositories completed under that
rule hold filenames whose `NNNN` is a small ordinal unrelated to the plan.
**Leave those alone** — renaming history to match a new rule breaks the links
that already point at it, and the rule earns its keep on the plans still to
come.

The counter was replaced because it lost the only identifier anyone cites. After
the move, nothing in the filename said which plan the file was, so every "plan
013" reference in a README, a decision record or another plan's dependency graph
became unresolvable — and a project that checks for dangling plan references
fails the moment a plan completes. The counter also failed at being an ordinal:
across the projects using it, seven pairs of files share a `YYMMDD.NNNN` prefix,
because step 4's scan is easy to skip and nothing downstream notices.

A plan number is unique per repository by construction, so it needs no scan, and
it is the string a reader already has in hand.

**What would reverse this:** a project that numbers plans non-uniquely, or one
that reuses numbers across a `plans/history/` archive. Neither exists today; the
first one to appear is the argument for going back to a counter, and it would
need the collision guard in step 4 either way.
