---
name: cli-openrouter
description: Use OpenRouter models through the bundled CLI for explicitly requested models, primary-model fallback, model comparison, or cheap mechanical text-in/text-out tasks.
---

# OpenRouter CLI

OpenRouter provides access to models from multiple providers through the bundled `openrouter-cli`.

It is a **metered external resource**. Use it deliberately, not as a default replacement for Claude, Codex, Gemini, or the current session.

The API key is `AI_OPENROUTER_KEY`. Both scripts read it themselves, in this order: the environment, `${XDG_CONFIG_HOME:-$HOME/.config}/cli-openrouter/.env`, `${CLAUDE_SKILL_DIR}/.env`, then the macOS keychain item (account `$USER`) whose service `MACOS_KEYCHAIN_AI_OPENROUTER_KEY` names in the environment or either `.env` file. `${CLAUDE_SKILL_DIR}/env.example` shows the file format. A key the API rejects falls through to the next source. Never read the key yourself.

Never print, log, commit, or expose the key.

## When to use

Use OpenRouter when:

- the user explicitly requests `openrouter`;
- the user requests a specific model through OpenRouter;
- a primary model or integration is unavailable or out of quota;
- a simple mechanical task can be handled more cheaply by an OpenRouter model;
- comparing or testing specific OpenRouter models is itself the task.

Typical cheap tasks:

- rewriting or tightening existing text;
- summarizing or condensing supplied text or logs;
- classification and extraction;
- translation of fixed text;
- boilerplate generation.

Do **not** use OpenRouter merely because it is available.

Routing by model: Claude models (`opus`, `sonnet`, `haiku`, `fable`) always run through
Claude Code (`claude -p`, the subscription), never through OpenRouter. `luna` runs through
Codex (the `codex` CLI, the plan) first; OpenRouter's `luna` is the fallback only when the
Codex lane is unavailable or failing. Any other paid model through OpenRouter is a rare
exception that needs a stated reason, unless another skill routes it here.

Tasks requiring strong judgment, architecture, serious code review, or broad repository understanding should normally stay with the primary agents/models unless OpenRouter or a particular model is explicitly requested.

## CLI

Canonical invocation:

```bash
openrouter-cli [-t TIER|-m MODEL] [-s SYSTEM] [-n MAX_TOKENS] [-T TEMP] [--think [low|medium|high]] 'PROMPT'
```

Inspect current spending and free-request usage:

```bash
openrouter-cli budget
```

Query the live model catalog, including current pricing and context limits:

```bash
openrouter-cli models [SUBSTRING]
```

Do not rely on remembered model availability, identifiers, context limits, or pricing when they matter. Query the live catalog.

OpenRouter model catalog:

https://openrouter.ai/models

Documentation:

https://openrouter.ai/docs

## Input

With only an argument:

```bash
openrouter-cli 'PROMPT'
```

the argument is the prompt.

With piped input and an argument:

```bash
some-command | openrouter-cli 'INSTRUCTION'
```

the argument is the instruction and stdin becomes the context.

Prefer this form for substantial input:

```bash
git log -1 --pretty=%B | openrouter-cli -t free \
  'Rewrite as a Conventional Commits header. Output only the header.'
```

Send only context relevant to the task.

Do not blindly send entire repositories, large diffs, huge logs, conversation histories, or unrelated files.

## Tiers

The CLI defines the actual tier-to-model mappings and is the source of truth.

| Tier | Use |
|---|---|
| `free` | Default for mechanical, easily checkable work |
| `cheap` | When free models are inadequate or reliability matters more |
| `luna` | Higher-quality output when the result should land correctly |

Default to:

```bash
-t free
```

Step up only when justified.

Use:

```bash
-m MODEL
```

when a particular model is explicitly requested or the task requires one.

Find current model IDs with:

```bash
openrouter-cli models SUBSTRING
```

Do not duplicate the tier's model lists in this skill. They change over time and are maintained by the CLI.

Models reached only through OpenRouter have aliases in this skill's `models.json`
(`grok`, `muse`), resolved by `model-id --openrouter ALIAS`. Which of them a contested
review call uses, step by step, is set in `workflow` `references/review.md`.

## Cost discipline

OpenRouter uses prepaid credits.

Rules:

1. Do not call it unnecessarily.
2. Default to the cheapest adequate tier.
3. Avoid duplicate calls and speculative retries.
4. Minimize input context.
5. Use `openrouter-cli budget` before substantial batch work.
6. Do not automatically run multiple models unless comparison is part of the task.
7. Do not enable reasoning for mechanical work.

Reasoning is disabled by default by the CLI.

Enable it only when the selected model and task genuinely benefit from reasoning:

```bash
openrouter-cli --think low '...'
openrouter-cli --think medium '...'
openrouter-cli --think high '...'
```

## Sensitive data

Treat OpenRouter as an external service.

Do not send:

- secrets or credentials;
- `.env` contents;
- API keys or tokens;
- customer-sensitive data;
- private data unrelated to the task.

Do not send private repository code to free or unknown providers unless explicitly permitted.

Redact sensitive information before sending context.

## Failures

The CLI handles provider fallback and transient retries internally.

If a request still fails:

1. read the actual error;
2. check the current model with `openrouter-cli models`;
3. check the budget with `openrouter-cli budget` when relevant;
4. verify current OpenRouter documentation if API behavior may have changed;
5. retry only after understanding the failure.

Do not repeatedly spend credits retrying the same unexplained failure.

## Output

Model output is not automatically authoritative.

For cheap and free tiers especially, inspect the result before using it. Mechanical output should be independently checkable.

When OpenRouter is used as a fallback for an important task, apply the same verification expected from the primary workflow.

## Principle

> Use OpenRouter when it provides clear value. Use the cheapest adequate model, send the minimum necessary context, and do not spend credits by default.

## Codex over OpenRouter

`codex-openrouter` (next to the CLI) runs `codex exec` with OpenRouter as the
model provider, default luna (`model-id --openrouter luna`), reading the key itself
(same lookup order as above). It is the `pipeline:engineer` agent's lane when the Codex plan is
out of quota: same harness, same model, paid from OpenRouter credits. It sends
repository code to OpenAI only — never point it at a free or unknown provider.
