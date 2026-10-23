---
name: ai-codex
description: Ask Codex (OpenAI's `codex` CLI, GPT models) a question or an alternative take on a plan, code fragment, or decision. Use only when the user asks for Codex by name ("спроси у codex", "уточни у codex", "что думает codex/gpt", "ask codex") or a review blocker is contested. A `review` or `second-opinion` request runs `second-opinion.sh` instead. Never call Codex on your own initiative.
---

# Ask Codex

`codex exec` runs OpenAI's agent CLI headless. Relay the answer attributed to
Codex, alongside your own view when they differ.

## When to call

Only when the owner asks for Codex by name or a review blocker is contested.
A `review` or `second-opinion` goes through `second-opinion.sh`
per `workflow/references/review.md`, not this skill. Otherwise no call
(AGENTS.md, external reviewers).

## Canonical invocation

```bash
printf '%s' "CONTEXT" | codex exec --ephemeral --skip-git-repo-check -s read-only \
  -m "$(model-id luna)" 'QUESTION' -o "$SCRATCHPAD/codex-out.txt" > "$SCRATCHPAD/codex-full.log" 2>&1
cat "$SCRATCHPAD/codex-out.txt"
```

Bash timeout of at least 300000 ms.

- stdin works: piped input is appended as a `<stdin>` block. Bulky context
  there, the question as the argument.
- `-o FILE` holds the final answer; stdout is chatty, hence the log file.
- `--ephemeral` keeps one-off calls out of session history;
  `--skip-git-repo-check` allows running outside git repos.
- `-C /path/to/repo` lets it read a repository itself; the read-only sandbox
  runs read commands without approval. Keep `-s read-only`, never
  `--dangerously-bypass-approvals-and-sandbox`.
- Never pipe codex stdout into `head` or anything closing the pipe early:
  codex dies on SIGPIPE and `-o` is never written.

## Model choice

Models are named by alias. The exact ids live only in
`${CLAUDE_SKILL_DIR}/models.json`; `model-id <alias>` (a command on `PATH`) prints one, and
`model-id --openrouter luna` gives the same model's OpenRouter id. A model upgrade
is a one-line edit there, nowhere else. Always pass `-m`: the account default in
`~/.codex/config.toml` (`medium` reasoning effort) is a convenience for manual use
and should name the same id as `luna`. Raise effort with
`-c model_reasoning_effort="high"` before the prompt.

| Use for | Invocation |
|---------|------------|
| quick questions, small checks (default) | `luna`: `-m "$(model-id luna)"` |
| mid-weight reviews | `terra`: `-m "$(model-id terra)"` |
| contested calls, architecture, tricky bugs | `sol`: `-m "$(model-id sol)" -c model_reasoning_effort="high"`; small quota, use sparingly |
| strongest option | `astra`: `-m "$(model-id astra)" -c model_reasoning_effort="high"` |

## Writing the prompt

- Codex sees nothing of this session: self-contained context (stdin block or
  `-C` workdir).
- One concrete question; ask for a verdict or ranked recommendation.
- For an independent check, do not reveal your own conclusion first.

## Reporting back

- Quote or faithfully summarize Codex's position, labeled as Codex (GPT).
- State your own position; on disagreement, say why and recommend. Never
  present its output as your own analysis.
