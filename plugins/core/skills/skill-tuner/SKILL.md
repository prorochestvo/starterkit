---
name: skill-tuner
description: Turn the owner's corrections into edits of EXISTING skills — triage each remark (skill, general behaviour, one-off, external), edit the target skill's instructions within the allowed scope, verify the diff, commit one change at a time with a revert path, and report. Use when a prompt starts with `~wtf` (or the typo `~wft`) or `~ok` (any case), when the owner asks to tune or fix a skill from a remark ("поправь скил по этому замечанию", "учти это в скиле"), or when captured remarks are queued for processing. Never creates, merges, promotes, or removes skills — that is skill-incubator.
---

# Skill Tuner

Keep existing skills aligned with the owner's corrections, without the owner having to stop
and edit them. A remark is evidence about one skill (or about general behaviour); the tuner
turns it into the smallest instruction change that would have prevented it.

**Status (2026-10-12):** manual mode, fully operational. The owner marks a prompt with
`~wtf` / `~ok` in the conversation; the agent that receives it runs the procedure below in
the same session. The automatic path (a detector on unmarked prompts and an end-of-act
trigger) is not built.

If the `skill-tuner-notify` skill is available, load it at the start of a run (pending notifications), at step 8 after the chat report, and when asked about or working on the automatic path.

## Authority

Governed by the owner's global instructions, section "Skills → Who may change what":

- Only this skill may change an existing skill's instructions (`SKILL.md`, reference
  documents) without a separate approval, within existing permissions and the target
  skill's own constraints.
- Executable code, scripts, and other executable assets: draft only, apply after the
  owner's explicit approval.
- Never create, merge, promote, or remove a skill (route new procedures to
  `skill-incubator`).

Models, by step (the owner's assignment):

| Step | Model |
|---|---|
| Orchestration and triage, every step (never writes the edit) | `opus`, effort `medium` |
| Edit wording (step 4) | `luna` via Codex: `-m "$(model-id luna)"` |
| Review chain (step 5) | `opus` → `fable` → `sol`, each at effort `medium` |

A session on any other model (`fable`, `sol`, `sonnet`, `haiku`, `luna`, `g-flash`, …) does not
orchestrate: it logs the remark as `queued` and, in Claude Code, hands steps 2–8 to an
`opus` subagent at effort `medium` with the collected remark; in Codex the remark stays
`queued`. `luna` falls back to `openrouter-cli -t luna`
only when the Codex lane is down; no other model stands in for `luna` or for a reviewer.

Draft only, never edit directly: anything under `skills/synced/` (vendor mirror, overwritten
by sync), the installed copies of plugin skills under the plugin cache (overwritten by every
update), and removing or weakening any `R#` rule in `common-contracts`. Public skills, those
of the starterkit plugins (`core:*`, `pipeline:*` and the others), are edited only through a
starterkit pull request (step 6); private skills stay in the owner's configuration
repository.
`AGENTS.md`/`CLAUDE.md`: draft only, per the owner's own rule in that file ("propose the
change, I apply it").

## Explicit markers

The owner may tag a prompt at its start (case-insensitive, optional colon):

- `~WTF` (typo alias `~wft`) — a correction: the owner is dissatisfied with the agent's work. Always a remark;
  no detector needed. Triage it like any other (step 2) — it can still be `none`.
- `~ok` — rare and optional: confirms an approach as the standard ("do it this way from now
  on"). Record what was confirmed so a later tuning step does not "fix" it away; it is a
  constraint for the target skill, not a change request.
- No marker carries no signal: an untagged prompt is neither approval nor complaint, and
  implicit dissatisfaction is the detector's job.

Optional area tag right after the marker: `~WTF[code]`, `~wtf[design]`, several as
`~WTF[code,tone]`. It names what went wrong, not which skill — triage still picks the
target. Known tags, so remarks group cleanly:

| Tag | Area |
|---|---|
| `code` | code written or changed |
| `design` | UI/UX, visual design |
| `plan` | plans, breakdowns, approach |
| `review` | review findings and their handling |
| `test` | tests and the gate |
| `docs` | docs, specs, READMEs, commit and PR text |
| `tone` | chat register, verbosity, explanations |
| `process` | workflow: asking vs deciding, order of steps, autonomy |
| `tool` | a CLI or skill tool used wrongly or misbehaving |

An unknown tag is kept as written and reported with the change, never dropped or
rewritten; if it recurs, propose adding it here.

Strip the marker and tag before any text reaches a detector or model scoring it; a marked
prompt is a free labelled example for measuring the detector, and the marker would give
the answer away.

## Procedure

Run it after the reply to the prompt itself: a marked prompt is still a request, so fix the
task first, then tune, then log. Everything below happens in the same turn.

1. **Collect the remark.** Marker, tags, the owner's words (cleaned: no secrets, tokens,
   hosts, or IPs — replace with `<redacted>`), one line on what the agent had just done,
   the project, and the skills invoked in this session. Never store or quote anything that
   looks like a secret.
2. **Triage the target** — exactly one of:
   - `skill:<name>` — an existing skill gave or allowed the behaviour the owner corrected;
   - `general` — agent behaviour not owned by any skill (candidate for `AGENTS.md`: draft only);
   - `none` — a one-off correction of this task; no rule follows from it. **Most remarks are this.**
     A preference about one project's own output (its message format, naming, layout) is
     `none` here: it belongs in that project's `AGENTS.md`, never in a global skill.
   - `external` — the owner is unhappy with a server, tool, or service, not the agent.

   The tag narrows the search (`[code]` → the language, lint, and contracts skills in play;
   `[process]` → `workflow`, `pipeline:*`), it never picks the skill by itself. `none` and
   `external` end at step 7 (log only). When unsure between `none` and a skill edit, choose
   `none`: an unnecessary rule costs more than a missed one.
   `~ok` follows the same steps: the confirmed approach becomes or sharpens a line in the
   target skill so a later remark does not tune it away; if it is a code standard, route it
   to `common-contracts` as an `R#` rule instead.
3. **Read the target skill fully** before editing, including the references it points to.
   Find whether the remark contradicts, refines, or is missing from what the skill says.
4. **Draft the smallest edit** that would have prevented the remark: one rule, example, or
   step — in the skill's own style, following the `writing-instructions` skill. The
   orchestrator states the change it wants (target file, what to sharpen or add, the
   constraints to keep); `luna` returns the whole new file, nothing else:
   `codex exec --ephemeral --skip-git-repo-check --ignore-user-config -s read-only
   -m "$(model-id luna)" -o <out> "<prompt>" </dev/null`, with the target file and the
   `writing-instructions` rules in the prompt. Build the diff yourself with
   `git diff --no-index <current file> <out>` — `luna` writes broken hunk headers, so it
   never writes the diff. Check the diff changes only what was asked; if not, re-ask `luna`
   once with the gap named — never edit its text yourself; still off → no edit, show the
   intended change in chat, status `drafted`. Codex down → `openrouter-cli -t luna "$(cat <prompt-file>)"`; both
   down → no edit, status `queued`. Nothing is written to the skill yet.
5. **Verify, then review the diff** — still unapplied:
   - confined to the target skill's instruction files;
   - no secrets, hosts, or IPs;
   - no contradiction with the owner's global instructions or other rules in the skill;
   - small (a few lines; a larger rewrite is drafted, not applied).

   Then the **review chain**, one reviewer after another, each in a fresh context and
   blind to the others' verdicts. Write the material to a file with the Write tool and pass
   it on stdin, never as an argument: the cleaned remark (English), the triage, the diff,
   the full target skill, the `writing-instructions` rules, and the "Who may change what"
   rules of the owner's `AGENTS.md`, with the instruction that there is no gate and the
   answer is one verdict line (`approve`/`revise`/`reject`) plus replacement text for
   each finding.
   1. `opus`: `claude -p --model opus --effort medium --setting-sources "" --tools
      "Read,Grep,Glob" --add-dir "${CLAUDE_SKILL_DIR}/.." < <file>`, told to search the
      skills for overlapping rules;
   2. `fable`: the same command with `--model fable`;
   3. `sol`: `codex exec --ephemeral --skip-git-repo-check --ignore-user-config -s
      read-only -m "$(model-id sol)" -c model_reasoning_effort="medium" -o <out> - < <file>`.

   A reviewer that cannot be reached stops the chain: no edit, nothing sent, status
   `queued`. Verdicts:
   - `approve` — the edit addresses the remark, is the smallest that would, and contradicts
     nothing in the skill, other skills, or the global instructions; pass to the next
     reviewer;
   - `revise` — with the concrete change; `luna` redrafts once and the chain restarts from
     `opus`;
   - `reject` — the remark is a one-off (`none`), the target is wrong, or the edit would
     overfit; stop, nothing to undo, status `rejected`.

   All three `approve` → copy `luna`'s reviewed file over the target and go to step 6.
   Draft-only targets (see Authority) and larger rewrites are shown in chat instead, status `drafted`; skip
   step 6. Any `revise` after the one redraft → do not apply: show the diff and every
   reviewer's position in chat, status `drafted`.
6. **Commit one change per remark** in the repository that holds the skill:
   - public skills (starterkit plugins): a branch in a starterkit clone, never `main`;
     push only after `public-gate.sh --range "<remote branch or base>..HEAD"` reports 0
     failing; write the PR title and body to files, gate each with `public-gate.sh --text`,
     then open the PR with `gh pr create --body-file`. Never edit `version`: the plugin
     version workflow stamps it. The change takes effect after the owner merges the PR and
     the hosts update the marketplace; log the PR URL in `note`, rollback is a revert PR;
   - private skills: the configuration repository that holds the skill — stage only the
     skill's own paths, never `git add -A`; other uncommitted files there belong to other
     sessions;
   - project skills (`.agents/skills/`): that project's repository, under its branch rules.

   Message `docs(<skill>): <subject>`, body one sentence of why, in plain
   prose: no remark id, tags, or marker (the store row links the remark to the sha). Rollback is `git -C <repo> revert <sha>`. Backing up the repository that holds the
   skill is the owner's sync, not this skill's step.
7. **Log the remark** in the store (below) with its triage, status, and commit sha.
8. **Report** in chat, one short block: triage, skill, what changed, and for `applied` the
   sha and the revert command (`drafted`: "not applied"). Then run the `skill-tuner-notify` step if that skill is available.

## Remark store

Monthly SQLite files `${CLAUDE_CONFIG_DIR:-$HOME/.claude}/runtime-state/skills/skill-tuner/YYYY-MM.sqlite`
(directory 0700, files 0600), outside git, kept 12 months; pruning and backup
are the owner's. Remark id: UTC timestamp `YYYYMMDDTHHMMSSZ`. Write the row as a JSON file
with the Write tool (keys as in the INSERT below; no shell quoting of the owner's text), then
insert it with parameters, never by pasting text into SQL:

```bash
python3 - /path/to/row.json "${CLAUDE_CONFIG_DIR:-$HOME/.claude}/runtime-state/skills/skill-tuner" <<'EOF'
import json, os, sqlite3, sys, time
row = json.load(open(sys.argv[1]))
d = sys.argv[2]; os.makedirs(d, mode=0o700, exist_ok=True)
p = os.path.join(d, time.strftime("%Y-%m", time.gmtime()) + ".sqlite")
new = not os.path.exists(p)
db = sqlite3.connect(p)
if new: os.chmod(p, 0o600)
db.execute("""CREATE TABLE IF NOT EXISTS remarks (id TEXT PRIMARY KEY, at TEXT, marker TEXT,
  tags TEXT, text TEXT, agent_did TEXT, project TEXT, skills TEXT, triage TEXT,
  status TEXT, commit_sha TEXT, note TEXT)""")
db.execute("INSERT OR REPLACE INTO remarks VALUES (:id,:at,:marker,:tags,:text,:agent_did,"
           ":project,:skills,:triage,:status,:commit_sha,:note)", row)
db.commit()
EOF
```

`marker`: `wtf` or `ok` (lower case, no `~`; `~wft` is `wtf`); `tags`: comma-separated,
as written; a field with no value is SQL `NULL`, never an empty string.
`status`: `queued` (waiting for a qualified model), `logged` (none/external), `applied`,
`drafted`, `rejected` (review said no), `reverted`. When the owner reverts
a change, update its row to `reverted` — a reverted remark is evidence against the edit.
