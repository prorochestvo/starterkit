---
name: task-management
description: The single source of the rules for project plans, owner feedback, and the project backlog under .agents/plans/ across every project. Load when discovering or executing an owner-feedback-YYYYMMDD.md file (earlier: review-YYYYMMDD.*); starting any new task while owner feedback is open; capturing a side-question, idea, or deferred concern that surfaced mid-task; deferring a review finding out of a cycle; naming a plan or backlog file (plan-name.sh, backlog-triage.sh --name); creating, reviewing, agreeing, completing, abandoning, or superseding a plan; turning an accepted backlog entry into a plan; listing the backlog ("что в беклоге", backlog-triage.sh --list); triaging the backlog ("разберём беклог", "triage the backlog", picking work with no instruction); or grooming it ("груминг беклога", "groom the backlog"). pipeline:working-agreement, pipeline:new-plan, and pipeline:complete-plan defer to this skill.
---

# Task management

The rules for three task records under `.agents/plans/`: plans, owner feedback, and
the backlog. This skill is the one source of those rules; the starterkit's
`pipeline:working-agreement`, `pipeline:new-plan`, and `pipeline:complete-plan` point here
rather than restating them.

- [references/plans.md](references/plans.md) — the `.agents/plans/` tree, plan naming and
  the fixed plan id, the plan template, review and agreement before implementation,
  completing, abandoning, and the legacy filename shapes. Load when creating, agreeing,
  completing, abandoning, or citing a plan, or when naming one.
- [references/owner-feedback.md](references/owner-feedback.md) — immutable owner-authored
  `owner-feedback-YYYYMMDD.md` files (earlier `review-YYYYMMDD.*`), all-items completion, the new-task gate,
  progress tracking, and archival. Load before selecting or starting new work and
  whenever owner feedback is present.
- [references/backlog.md](references/backlog.md) — listing the open entries; the gate that
  decides whether an entry is written; capturing side-questions, ideas, deferred concerns,
  and deferred review findings; priorities; the filename and its
  origin-plan prefix; triage and grooming; the external assessment before an entry becomes
  work; the accepted and dropped endings. Load when something surfaces mid-task that is not
  the task, when a review finding is deferred, or when the backlog is triaged or groomed.

This skill manages task records and their lifecycle; the `workflow` skill governs
engineering execution, including preflight, review, and verification. The pipeline
itself — who plans, who implements, who reviews — stays in `pipeline:working-agreement`.

Plan and backlog filenames are never hand-built; owner feedback filenames are supplied by the owner and are never renamed. The skill's scripts in
`${CLAUDE_SKILL_DIR}/scripts/`, on `PATH` under their own names, produce them: `plan-name.sh` for plans,
`backlog-triage.sh --name` for backlog entries.
