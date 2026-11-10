---
name: ai-gemini
description: Ask Gemini through OpenRouter when the user asks for Gemini by name ("спроси у gemini", "уточни у gemini", "что думает gemini", "ask gemini"), or through `second-opinion.sh` as the tie-break on a contested review blocker. OpenRouter spends prepaid credits. A `review` or `second-opinion` uses codex (`sol`), not Gemini. Never call Gemini on your own initiative.
---

# Ask Gemini

`openrouter-cli` sends one prompt to Gemini through OpenRouter; relay the answer
attributed to Gemini, alongside your own view when they differ.

## When to call

- The owner asks for Gemini by name.
- Agents cannot agree on a review blocker: `second-opinion.sh --tier 2` adds `g-pro`
  itself (`workflow/references/review.md`); never call it separately.

Nowhere else: a `review`'s external reviewers, a `second-opinion` and the working
agreement's external plan review run codex on `sol` (`ai-codex`). Otherwise no call
(AGENTS.md, external reviewers).

## Canonical invocation

```bash
openrouter-cli -m "$(model-id --openrouter g-pro)" --think high -n 8000 --timeout 300 "$(cat "$SCRATCHPAD/gemini-prompt.md")"
```

Gemini on OpenRouter requires reasoning: without `--think` the call answers 400.

Bash timeout of at least 310000 ms: pro models think slowly, and the request itself waits 300 s.

- Gemini sees only the prompt, so paste the relevant content.

## Model choice

Models are named by alias. The exact ids live only in
`${CLAUDE_SKILL_DIR}/models.json`; `model-id <alias>` (a command on `PATH`)
prints one. `model-id --openrouter <alias>` prints the OpenRouter id. A model
upgrade is a one-line edit there, nowhere else.

| Use for | Invocation |
|---------|------------|
| contested calls, architecture, tricky bugs (default) | `g-pro`: `-m "$(model-id --openrouter g-pro)" --think high` |
| quick checks, small questions | `g-flash`: `-m "$(model-id --openrouter g-flash)" --think low` |

## Writing the prompt

- Gemini sees nothing of this session: the question, the decision being
  weighed, and the relevant code/diff/plan inline, trimmed.
- Ask for a concrete verdict or ranked recommendation, not an essay.
- For an independent check, do not reveal your own conclusion first.

## Reporting back

- Quote or faithfully summarize Gemini's position, labeled as Gemini's.
- State your own position; on disagreement, say why and recommend. Never
  present its output as your own analysis.
