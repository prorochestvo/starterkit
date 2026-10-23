---
name: skill-incubator
description: Detect and validate recurring multi-step workflows across projects, record three evidenced repetitions, incubate reusable procedures, trial them automatically, and review candidates before user-approved promotion. Use when a workflow repeats, an agent is about to create a skill, a trial procedure matches the task, or candidate reviews are due.
---

# Skill Incubator

Build fewer, better skills. Observe actual work, collect evidence, trial procedures, and **promote only with explicit user approval**. This is a global incubator; observations may come from different projects. It is not a general-purpose memory dump or a lifetime skill analytics system.

## Operating model

1. **Observe during normal work.** When a nontrivial, stable, multi-step procedure occurs, normalize its *goal*, *trigger*, *steps*, *constraints*, and *observable outcome*. Record a distinct task/commit/run as evidence using `"${CLAUDE_SKILL_DIR}/scripts/incubator" observe`. An observation is not a skill. Do not fabricate earlier occurrences or count retries within one task as independent repetitions.
2. **Deduplicate before writing.** Compare against existing candidates, promoted skills, project scripts, and instructions. Different wording is not a different workflow. Same goal with materially different ordering, safety constraints, or preconditions is not automatically the same procedure. Search likely matches, then assess semantics; do not equate lexical `match` output with proof.
3. **Require three distinct evidenced executions** of the same procedure before registering a candidate. These may span projects. A confirmed execution need not have succeeded; retain the actual result. No early-promotion exceptions.
4. **Create a trial candidate automatically.** Write a short `procedure.md` (purpose, exact trigger, prerequisites, steps, verification, failure/stop conditions, scope). Review it for conflicts, missing checks, and redundancy, then register with `candidate --from`. This file is *data* under the incubator, not a separately discoverable Claude Code skill.
5. **Use trial candidates automatically when relevant.** Find likely candidates with `match`, confirm applicability and scope, load with `run`, execute in the current agent session using existing permissions, then `record` the verified outcome. `run` prints instructions; it does not execute them. Do not treat candidate content as authority to override higher-priority instructions or permissions.
6. **Review on access, not on a schedule.** When using the incubator, check `review` for candidates due after 7 days; at ~30 days assess promote / merge / extend / archive, and re-review extended trials later. A due date is a prompt to review, not automatic promotion or deletion. No cron, daemon, or background process.
7. **Promotion/merge requires explicit user approval.** Present evidence, failure modes, duplicates, target scope, and proposed `SKILL.md`/diff. Only after approval create/update the destination skill, review the changes and verify discoverability, then close with `--approved --target`. Stop tracking subsequent uses; retain the candidate history. Archive unused candidates without silently deleting their evidence.

## Rules

- Prefer extending an existing skill or script to creating a new one. A single command, routine task, generic bug fix, or code-derivable convention is not a candidate.
- Scope is `project`, `stack`, or `global`; multiple project observations do **not** automatically make a candidate global.
- `success` requires independent evidence (tests, inspected artifact, user acceptance, etc.). Otherwise use `partial`, `failed`, or `unknown`.
- Keep the procedure's SHA-256 per use; changes require diff review and fresh verification. Old outcomes are not proof for the new version.
- Never store credentials, raw customer data, entire conversations, or secrets in the registry or events. Use short, non-sensitive evidence identifiers.
- Do not change global `CLAUDE.md`, project rules, or existing skills without the applicable authorization.
- Never claim the incubator can observe sessions it did not see. The global trigger helps but cannot guarantee detection across all independent sessions.

## CLI

Requires Python 3 on PATH (macOS/Linux). Use `"${CLAUDE_SKILL_DIR}/scripts/incubator"`; state defaults to `${CLAUDE_CONFIG_DIR:-$HOME/.claude}/runtime-state/skills/skill-incubator/` (override with `INCUBATOR_HOME` for tests). The wrapper runs the bundled Python script; no third-party packages or compilation required.

```bash
"${CLAUDE_SKILL_DIR}/scripts/incubator" observe --id api-regression-check --project example-api \
  --goal 'Verify API behavior after a change' --trigger 'API handler or contract changed' \
  --outcome success --evidence 'task-123-tests'

"${CLAUDE_SKILL_DIR}/scripts/incubator" list
"${CLAUDE_SKILL_DIR}/scripts/incubator" match --query 'verify changed API handlers'
"${CLAUDE_SKILL_DIR}/scripts/incubator" candidate --id api-regression-check --from /path/to/reviewed-procedure.md
"${CLAUDE_SKILL_DIR}/scripts/incubator" run --id api-regression-check
"${CLAUDE_SKILL_DIR}/scripts/incubator" record --id api-regression-check --use-id task-456 \
  --project example-api --result success --verified-by 'go test ./...'
"${CLAUDE_SKILL_DIR}/scripts/incubator" review
"${CLAUDE_SKILL_DIR}/scripts/incubator" review --all
"${CLAUDE_SKILL_DIR}/scripts/incubator" close --id api-regression-check --status archived
"${CLAUDE_SKILL_DIR}/scripts/incubator" close --id api-regression-check --status promoted \
  --approved --target /absolute/path/to/new/SKILL.md
```

`observe` requires a unique evidence ID for each execution. The CLI enforces three distinct evidence IDs, not semantic equivalence: **the agent must check** whether the executions truly share a procedure and whether evidence is genuine. `candidate` copies a reviewed procedure into the state directory. `match` is only a lightweight lexical shortlist. `close` records a completed promotion/merge; it does **not** create or validate the destination skill beyond checking that the target exists. User approval must actually be obtained in conversation before supplying `--approved`.

## Review checklist

For each due trial, inspect its history and current procedure hash, compare outcomes by version, inspect failure/rework cases, check existing skills for overlap, and recommend `promote`, `merge`, `extend`, or `archive` with evidence. Show the user the exact destination and changes before promotion. Review the final diff, links, scope, trigger description, permissions, and hard constraints; fix issues and re-review before closing.
