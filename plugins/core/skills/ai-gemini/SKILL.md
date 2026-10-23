---
name: ai-gemini
description: Ask Gemini a question or an alternative take on a plan, code fragment, or decision - through the local `agy` CLI when the user asks for Gemini by name ("спроси у gemini", "уточни у gemini", "что думает gemini", "ask gemini"), through OpenRouter as the tie-break when agents cannot agree on a review blocker. A `review` or `second-opinion` uses codex (`sol`), not Gemini. Never call Gemini on your own initiative.
---

# Ask Gemini

`agy -p` runs Google's agent CLI in print mode. Relay the answer attributed to
Gemini, alongside your own view when they differ.

## When to call

- The owner asks for Gemini by name: `agy`, below.
- Agents cannot agree on a review blocker: `g-pro` through OpenRouter, below, as the
  extra opinion that breaks the tie (`workflow/references/review.md`).

Nowhere else. Wherever `g-pro` used to be required - a `review`'s external
reviewers, a `second-opinion` - codex runs `sol` instead (`ai-codex`). Otherwise
no call (AGENTS.md, external reviewers).

## Canonical invocation

By name, through `agy`:

```bash
agy --model "$(model-id g-pro)" --effort high -p 'PROMPT' 2>&1
```

Tie-break, through OpenRouter (prepaid credits; reasoning is mandatory for this
model, so `--think` is required or the call answers 400):

```bash
openrouter-cli -m "$(model-id --openrouter g-pro)" --think high -n 8000 "$(cat "$SCRATCHPAD/gemini-prompt.md")"
```

Bash timeout of at least 300000 ms: pro models think slowly and `agy`'s own
`--print-timeout` defaults to 5m.

- Flag order matters: `-p` takes the prompt as its value and nothing after it
  is parsed as a flag. Every other flag goes before `-p`.
- stdin is ignored in print mode; all context goes inline in the `-p` string.
- No file access in print mode (tool permissions are auto-denied): read the
  files yourself and paste the relevant content.
- Big prompts: write to a scratch file to avoid quoting pain:
  `agy --model "$(model-id g-pro)" --effort high -p "$(cat "$SCRATCHPAD/gemini-prompt.md")" 2>&1`

## Model choice

Models are named by alias. The exact ids live only in
`${CLAUDE_SKILL_DIR}/models.json`; `model-id <alias>` (a command on `PATH`)
prints one. A model upgrade is a one-line edit there, nowhere else.

| Use for | Invocation |
|---------|------------|
| contested calls, architecture, tricky bugs (default) | `g-pro`: `--model "$(model-id g-pro)" --effort high` (low, medium or high) |
| quick checks, small questions | `g-flash`: `--model "$(model-id g-flash)" --effort medium` |

## Writing the prompt

- Gemini sees nothing of this session: the question, the decision being
  weighed, and the relevant code/diff/plan inline, trimmed.
- Ask for a concrete verdict or ranked recommendation, not an essay.
- For an independent check, do not reveal your own conclusion first.

## Reporting back

- Quote or faithfully summarize Gemini's position, labeled as Gemini's.
- State your own position; on disagreement, say why and recommend. Never
  present its output as your own analysis.
