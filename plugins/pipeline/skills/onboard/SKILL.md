---
name: onboard
description: Verify and finish wiring a project into the starterkit - fresh install after install.sh or migration of an existing project. Checks marketplace wiring, permissions, legacy agents/commands, AGENTS.md shape, plans layout, agent memory, and gitignore; fixes the mechanical parts, reports what needs a human call.
---

Run the onboarding checklist below against this project. **Fix mechanical items
directly; collect judgment items into a punch list** for the user instead of acting
unilaterally. Finish with a status table (✅ / 🔧 fixed / ⚠️ needs decision) and the
punch list.

Throughout: the legacy component set varies per repo (some have `.claude/commands/`,
some don't; memory dirs may be partial) — check existence before every removal or
rename; never assume the full set, never let one missing path abort the run.

## 0. Branch & sync (do this first)

- `git fetch`; note the remote default branch AND the actual active trunk — they
  differ (a `v1` or long-lived `refactoring` branch may be the real line of work,
  with the default branch a stale fragment). The Claude setup may exist on only one
  branch: **migrate the branch that owns the setup and carries active work.**
- `git pull --ff-only` the target branch before touching anything; surface dirty
  files and unpushed commits instead of working around them.
- If active work lives on a different branch than the one migrated, plan the merge
  into it (resolve CLAUDE.md in favor of the working branch's project facts) — a
  migrated default branch nobody works on helps no one.
- Surface remote quirks: a renamed repository (update the origin URL) and
  PR-protection on the target branch (pushing may rely on owner bypass — ask
  whether to push directly or open a PR).

## 1. Marketplace wiring (mechanical)

- `.claude/settings.json` exists, is committed (check the project's `.gitignore`
  whitelists it), and contains `extraKnownMarketplaces.starterkit` plus
  `enabledPlugins` for `pipeline@starterkit`, `knowledge@starterkit`, and the stack
  plugin matching the repo (`go.mod` → `stack-go`, `pubspec.yaml` → `stack-flutter`).
- Missing entirely → tell the user to run `install.sh <stack> .` from the starterkit
  repo (do not hand-assemble a fresh install). Missing keys in an existing file →
  add them.

## 2. Permissions (mechanical + report)

- Apply the `pipeline:sync-permissions` procedure: merge the canonical fragments
  additively, report added entries and local extras.
- Flag blanket footguns in allow lists as ⚠️: `Bash(git *)`, `Bash(ssh *)`,
  `Bash(rm *)`, blanket `WebFetch`/`Read` on broad paths — recommend the canonical
  narrow equivalents; do not remove without the user's call.
- Flag allow entries for commands that spend money (paid APIs, deploy triggers) as ⚠️.
- `.claude/settings.local.json`, if present: report entries now covered by canon
  (safe to prune) and dead entries (paths to renamed/removed projects, one-off
  session approvals). Prune only with the user's OK.

## 3. Legacy agents and commands (judgment)

- **Harvest before deleting.** Read every legacy agent/section and split its content
  three ways: a *project fact* → a CLAUDE.md section (visible to ALL roles, not
  locked in one agent's prompt); a *general rule* good for every project → propose
  adding it to the starterkit canon (stack conventions or a knowledge skill); noise →
  delete. Real examples: a test-only-code placement rule harvested into
  `stack-go:conventions`; a site reviewer's SEO/a11y checklist preserved as a
  project focus override.
- `.claude/agents/*.md` duplicating pipeline roles (architect/engineer/reviewer/
  testdoctor under any naming — `gocode-*`, `site-*`, `flutter-*`) → ⚠️ recommend
  deletion after harvesting; the plugin provides the roles.
- Project-specific specialist agents → ⚠️ recommend folding: project facts into a
  CLAUDE.md section, method/doctrine into an existing knowledge skill (or propose a
  new one in the starterkit). An agent stays only if it is a genuinely distinct
  *role*, not knowledge + facts.
- `.claude/commands/new-plan.md` / `complete-plan.md` → superseded by pipeline
  skills; recommend deletion.
- **Project-local skills are residents, not legacy** — keep them. They live in
  `.agents/skills/`, and `.claude/skills` is a committed relative symlink to
  `../.agents/skills` so Claude Code still finds them. A real `.claude/skills/`
  directory → if `.agents/skills/` holds nothing but `.gitkeep`, remove it entirely
  (`git rm -r`, or `rm -r` when untracked) so `git mv` does not nest; then
  `mkdir -p .agents && git mv .claude/skills .agents/skills &&
  ln -s ../.agents/skills .claude/skills`, then re-point `.claude/skills/` path
  references to `.agents/skills/`; both a real `.claude/skills/` and a non-empty
  `.agents/skills/` → stop, merging them is the owner's call. Make sure the
  `.gitignore` policy lets `.agents/skills/` and the link through: git sees the link as
  a file, so under `.claude/*` it needs `!.claude/skills` without the trailing slash
  (`!.claude/skills/` re-includes only a directory and silently drops the link).
  Confirm with `git ls-files -s .claude/skills` showing mode `120000`.

## 4. AGENTS.md shape (judgment)

- `AGENTS.md` is the regular file and `CLAUDE.md` a relative symlink to it
  (`CLAUDE.md -> AGENTS.md`), so Codex and Claude Code read one source. Mechanical fix:
  only `CLAUDE.md` exists → `git mv CLAUDE.md AGENTS.md && ln -s AGENTS.md CLAUDE.md`;
  only `AGENTS.md` → add the link; `AGENTS.md` is a link to `CLAUDE.md` →
  `git rm -q AGENTS.md && git mv CLAUDE.md AGENTS.md && ln -s AGENTS.md CLAUDE.md`;
  both are regular files → identical: replace
  `CLAUDE.md` with the link; different: stop and show the diff, merging them is the
  owner's call. Commit this alone, apart from any content edit.
- No unfilled `<...>` placeholders (fresh install: walk the user through
  filling them from the actual repo — versions, layers, routes, env vars, deps).
- No sections restating stack-plugin conventions (test structure, declaration order,
  error-contract boilerplate, code organization, godoc rules) → recommend replacing
  with one pointer line; keep only project-specific overrides and additions.
- **Overrides of the canon are called out explicitly**, never kept silently: the
  pointer line states "where this file contradicts the skill, this file wins" and
  each override names what it overrides (real examples: stdlib-only testing — no
  testify; no `-race` on arm64; throw/catch-log error handling instead of a Failure
  hierarchy). A silent override gets "fixed" back to canon by some future session.
- Has the **Working agreement** section (pipeline stages, gates, P0-P3, plan
  lifecycle). Older pipelines (a different number of parallel reviewers,
  single-reviewer flows, Blocker/Major scales) → ⚠️ recommend the standard block;
  preserve deliberate project overrides (e.g. a domain-specific reviewer focus) as
  named overrides inside the working agreement.
- Build/test/lint gates documented and **actually pass** — run them; a red tree is a
  ⚠️ finding, not a blocker for onboarding.

## 5. `.agents/` layout (mechanical)

- Legacy root `plans/` exists → migrate it, in two commits:
  1. **Move.** If `.agents/plans/` holds nothing but `.gitkeep` files, remove it entirely
     (`git rm -r`, or `rm -r` when untracked) — an empty directory left behind makes
     `git mv` nest the tree; if it holds anything else, stop and report both trees, since
     merging two numbered trees is the owner's call. Move a root `plans/documentations/`
     to `.agents/specs/` first, then `mkdir -p .agents && git mv plans .agents/plans`.
     Commit the moves alone, so `git log --follow` keeps each file's history.
  2. **Re-point.** Rewrite `plans/` path references in `CLAUDE.md`/`AGENTS.md`,
     `.claude/`, and `.agents/` itself to `.agents/plans/`, and commit that separately.
- `.agents/plans/`, `.agents/plans/completed/`, `.agents/plans/history/`,
  `.agents/plans/backlog/`, `.agents/specs/`, `.agents/scripts/`, `.agents/skills/` exist
  (create with `.gitkeep`), and `.claude/skills` is the link to `../.agents/skills`
  (absent → `ln -s ../.agents/skills .claude/skills`).
- Stale active plans (`.agents/plans/NNN-*.md` for work that shipped or died) → ⚠️ list them;
  completed → `pipeline:complete-plan`, abandoned → `.agents/plans/history/`.

## 6. Agent memory (mechanical + judgment)

- `.claude/agent-memory/<old-agent-name>/` dirs from renamed agents → rename to the
  pipeline names (`architect`, `engineer`, `reviewer`, `testdoctor`) so accumulated
  memory survives. A fixer/doctor-style agent maps to `testdoctor`.
- Read the memory files: `feedback_*` with live rules → keep (verify claims against
  the code, not from memory); `project_*` describing shipped/dead work → ⚠️
  recommend deletion; update each `MEMORY.md` index after changes.
- **Decide and record the memory tracking policy**: gitignored (machine-local, the
  default) vs committed via `!.claude/agent-memory/` whitelist (memories travel
  across machines — right when they hold real content and the repo is worked from
  several machines). Either is fine; pick one deliberately.

## 7. Hygiene (mechanical)

- `.gitignore` covers: `.claude/settings.local.json`, `.DS_Store`, and the stack's
  build/scratch/log dirs per conventions (`build/`, `tmp/`, `logs/` for Go).
- Delete stray `.DS_Store` files; flag leftover artifacts from renamed/dead projects.

## 8. Other machines (report)

Machine-local state does not travel with the repo. For every other machine that
works with this project (laptop, Raspberry Pi, servers), the punch list must name
the per-machine steps:

- `git pull` the migrated branch.
- Rename untracked `.claude/agent-memory/<old-name>/` dirs there too (each machine
  has its own copies when memory is gitignored).
- Register or refresh the marketplace (`claude plugin marketplace add/update`) and
  update stale plugin caches; prune that machine's `settings.local.json` if asked.

## 9. Final verification

- Confirm the session sees the pipeline agents and stack/knowledge skills (fresh
  shells: the user may need one interactive `claude` start to accept the trust
  dialog and marketplace install prompt — headless runs skip permissions until then).
- Print the status table and the punch list of ⚠️ decisions.
