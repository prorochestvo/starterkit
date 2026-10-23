---
name: workflow
description: Development workflow for repository and host changes - the implement/gate/commit/review/push sequence, the gate and its fallback, preflight before touching a repository or host, read-only status reports and multi-repo sweeps, the review cycle, and extraction of reusable standards.
---

# Development workflow

Apply this skill when implementing or reviewing development changes, when reporting the state of a repository or host, and before a sweep across several of them. Follow the global `AGENTS.md` permissions and the existing `pipeline:*` specialists. Load only relevant references, without weakening mandatory steps.

| Reference | Load when |
|---|---|
| `references/preflight.md` | Before acting on or reporting about an unopened repository/host, or before a sweep across several |
| `references/verification.md` | Implementing or verifying code changes |
| `references/review.md` | Running the mandatory review cycle or a requested review |
| `references/standards-extraction.md` | User feedback or review yields reusable rules |

## The sequence

Once a task is understood and any stated blocker is resolved, run it end to end without progress check-ins and without asking to start the next agreed item:

1. implement;
2. run the gate;
3. commit;
4. the parallel reviewers (`references/review.md`); fix their findings; re-run the gate;
   commit;
5. the standards audit (`code-standards-auditor`, `references/review.md`); fix its
   findings; re-run the gate; commit;
6. push (branch rules in `cli-git`);
7. report once, at the end.

Commit before every reviewer, never after: reviewers hold write tools and may check out other revisions. Do not invoke external reviewers unless `references/review.md` permits it. `cli-git` governs Git mechanics; `cli-github` governs GitHub operations; `common-contracts` governs implementation requirements. Rule extraction is event-driven, not an obligatory step after every review.

## The gate

The gate is `verification` per the glossary: `make verify` (linters, static analysis, tests). A repository without that target does not stop the work:

- run its documented checks instead - README or CI config: tests, lint, static analysis;
- none documented: proceed and say so in the report;
- either way, propose the missing `make verify` target in the final report;
- never improvise a gate: do not invent a check the repository does not document and present it as the gate.

The same applies to `make test` and `make deploy`: a missing target is reported with a proposal, not replaced by an ad-hoc command.

## Reporting

One report at the end of the sequence: what changed, the gate's result (or that no gate exists and what was run instead), the review outcome, the commits and the push, backlog entries filed, and any proposal (gate target, follow-ups). Steps only the owner can run are handed over as one runnable command (`common-contracts`, owner-only actions), never as a prose blocker list.
