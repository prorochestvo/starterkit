---
name: new-plan
description: Create a new plan file in plans/ with the standard task-breakdown template. Use when starting any non-trivial piece of work that needs a plan before implementation.
argument-hint: <slug-in-kebab-case>
---

Create a new plan file in `plans/` for the slug `$ARGUMENTS`.

Steps:

1. Validate that `$ARGUMENTS` is non-empty and kebab-case (lowercase letters, digits, hyphens). If not, stop and ask for a valid slug. The slug must describe intent (`add-rate-limiting`, not `task`).
2. Determine the next plan number `NNN`:
   - List `plans/*.md`, `plans/completed/*.md`, `plans/history/*.md`.
   - Take the highest `NNN` across `NNN-*.md` files in `plans/` and `plans/history/`, increment by 1, zero-pad to 3 digits. Start at `001` if none exist.
3. Write `plans/NNN-$ARGUMENTS.md` with this template:

```markdown
# Task Breakdown

<!-- only when this plan comes from a backlog entry: -->
- backlog: YYMMDD.NNNN.slug (raised <YYYY-MM-DD>)

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

4. If the plan originates from a `plans/backlog/` entry: move that entry's
   content into the plan, fill the `backlog:` header line, and **delete the
   backlog file** — accepted work is tracked as a plan, never in both places.
   Stage the deletion together with the new plan so one commit carries the
   handover.
5. Report the created path, the chosen number, and the backlog entry it
   consumed, if any.

Do not write any production code. This skill only creates the plan file.
