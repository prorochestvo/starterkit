---
name: writing-instructions
description: Write and optimize instructions for AI agents — AGENTS.md/CLAUDE.md, a skill's SKILL.md and references, agent definitions, and agent specs under .agents/specs/. Use when creating or editing any of them, when a remark concerns how instructions are written ("пиши фактами", "это не инструкция, а теория"), when skill-tuner edits a skill, or when instruction files grow, duplicate content, or need review, compression, or restructuring (target 20 KiB per file). Not for deciding whether to create a skill (skill-incubator), processing a ~wtf/~ok remark (skill-tuner), or human docs and READMEs (common-contracts documentation).
---

# Writing instructions

An instruction file is read by an agent on every task it covers, for months. Every line
costs tokens each time and is taken as true. Write so that the agent acts correctly
without asking, and so that nothing in the file turns false while it sits there.

Two modes: **Write** (creating or changing instructions) and **Optimize** (auditing and
compressing existing instruction files). Both follow the rules below.

## Writing rules

- **Facts, not possibilities.** State what is true now: commands that work, values that
  hold, rules that apply. No "might", "check whether", "if X is restored", alternatives, or
  pending work — those belong in plans. Settle an open question with the owner before
  writing it down. The documentation contract in `common-contracts`
  (`references/documentation.md`) holds the same rule for docs and specs.
- **Claims match enforcement.** An instruction may promise only what something enforces
  or what the agent is told to do (the rule R35 in `common-contracts` sets for comments, applied to
  instructions); no "always" or "never"
  that nothing backs.
- **Imperative and concrete.** "Run `make verify`", not "verification should be
  considered". Name the file, command, or value; examples only where the rule alone would
  be misread.
- **Point to code; don't copy it.** For identifiers, env vars, routes, or files declared in
  code, name the declaring file instead of listing them; write down only the convention and
  the exceptions the code does not show. Do not add a check, test, or lint that compares
  instruction text with code: if an instruction must change whenever the code changes, it
  is a copy.
- **One rule, one place.** Before adding a rule, search the skills, `common-contracts`,
  and the relevant `AGENTS.md` for one that covers it; sharpen that line instead of adding
  a second. Elsewhere, link to it — never copy it.
- **Why only when it prevents a wrong call.** Give the reason when an agent without it
  would "simplify" the rule away; otherwise leave it out. Decision history goes to plans,
  ADRs, or commit bodies.
- **Language.** English, in the owner's professional register. Data tokens (identifiers,
  config keys, scraped labels, the owner's trigger phrases in a description) stay
  byte-for-byte.
- **No secrets** — tokens, passwords, private keys, `.env` values — ever.

## Per file type

- **`AGENTS.md`** — follows R21 (`common-contracts/references/documentation.md`) and the
  owner's "Project layout" rules. The global `~/.claude/AGENTS.md` is draft only: propose
  the change, the owner applies it.
- **`SKILL.md`** — frontmatter `name` equals the directory name; `description` says what
  the skill does and when to use it, with the trigger phrases the owner actually uses (in
  the owner's language), and what it is not for when a neighbouring skill is easy to confuse. The
  body is the procedure; detail goes to `references/`, one level deep, each pointer saying
  when to read it. Scripts only for steps that must be deterministic.
- **Specs (`.agents/specs/`)** — contracts and runbooks: exact commands, values, and
  paths.
- **Agent definitions** — role, inputs, outputs, and limits; no project facts that belong
  in the project's `AGENTS.md`.

## Who may change what

The owner's global `AGENTS.md`, "Skills → Who may change what", governs every edit; this
skill adds no permission.

## Optimize

Optimize instruction files for **useful instructions per token**, not minimum length. Target **20 KiB (20,480 bytes) per file**, measured with `wc -c`. This is a project target, not a platform limit. If essential content exceeds it, report the excess rather than deleting critical instructions.

### Scope

- Inspect the requested instruction files (root and nested `AGENTS.md`/`CLAUDE.md`, `SKILL.md`, specs), including their relevant referenced documents.
- Read each target completely. Inspect code or referenced documentation before calling content redundant or derivable.
- Treat the global `~/.claude/AGENTS.md` as draft only (see Per file type).
- Preserve project-specific overrides and the distinct audiences of `CLAUDE.md` and `AGENTS.md`. Never assume one is automatically loaded by agents using the other.

### What to keep

- Project map, architecture, ownership boundaries, and important entry points.
- Hard rules, security invariants, non-obvious exceptions, and operational constraints.
- Concise cross-cutting conventions and essential build/test/deploy commands.
- Short pointers to authoritative skills, specs, or runbooks, with triggers for when to read them.
- Non-obvious rationale only when its absence would invite a wrong decision.

### What to move or remove

- Reusable cross-project workflows and conventions → **propose** a skill (e.g. `common-contracts`); never silently make a project rule global.
- Detailed project architecture, API/protocol contracts, runbooks → version-controlled specs/docs, linked from the instruction file.
- TODOs, temporary work, parked refactors → issues/plans.
- Incident chronology and historical decisions → ADR/history if still useful.
- Enumerations of endpoints, config keys, methods, migrations, etc. declared in code → a pointer to the declaring file (see "Point to code" in Writing rules); keep shared conventions and genuine exceptions. Remove any check that pins instruction text to code; if it lives in project code, propose the removal instead of making it.
- Duplicated instructions and verbose examples → one authoritative statement plus a link.

Do not use agent auto-memory as a replacement for durable, version-controlled project rules.

### Procedure

1. **Discover:** find relevant instruction files, their scopes, sizes in bytes, and referenced materials.
2. **Classify:** label sections `KEEP`, `REMOVE`, `REWRITE`, or `MOVE`. For lists, consider extracting a common convention plus exceptions; do not automatically delete lists.
3. **Check recoverability:** before cutting, ask whether an agent can reliably reconstruct the information from code or an accessible linked source. If not, preserve it or prepare an authoritative destination.
4. **Report:** show current and projected size per file, highest-impact changes, exact text/diff of proposed removals or rewrites, destinations for moves, and uncertainties. Flag security-sensitive changes.
5. **Apply:** default to waiting for approval of the proposed set. If the user explicitly requests direct optimization, apply safe changes without extra confirmation; ask about ambiguous/high-risk removals. An approved batch does not require per-block confirmation.
6. **Review changes:** inspect the complete diff against the originals, not just the resulting file. Check every removal, rewrite, and move for lost requirements, changed meaning, broken precedence, missing exceptions, accidental scope expansion, and unintended edits. Confirm that extracted skills/specs preserve the full contract and are discoverable by the intended agent. Fix findings and review the diff again.
7. **Verify:** re-read edited files; check links, identifiers, commands, rule precedence, and that the intended agents can reach referenced instructions. Report final sizes, savings, diff summary, review findings/fixes, and any remaining overage.

### Non-negotiable safeguards

- Never delete security/authentication/authorization invariants, data ownership boundaries, fail-closed rules, or content the user explicitly asked to retain just to meet the target.
- Preserve exact commands, identifiers, data tokens, exceptions, and meaning. Do not silently weaken requirements.
- Never claim a moved rule is available until its destination exists and is reachable. If moving files is not approved, propose the move and keep the source intact.
- If both formats coexist, do not replace one with a bare reference to the other unless that agent can access it.
- Do not change application code as part of this optimization.

### Output

Respond in the user's language; persistent files follow the writing rules above (English). Summarize files inspected, original → final byte sizes, removed/rewritten/moved content, new reference paths, review results and fixes, unresolved decisions, and files still above 20 KiB.
