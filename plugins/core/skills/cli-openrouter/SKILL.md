---
name: cli-openrouter
description: Access OpenRouter models via one CLI for explicitly requested models, independent code and architecture reviews, model comparisons, primary-model quota fallback, and cost-conscious text analysis, and choose which OpenRouter model fits a task from the curated catalog `models.toml`. Claude Code remains the execution agent.
---

# OpenRouter CLI

OpenRouter provides access to models from multiple providers through the bundled `openrouter-cli`.

It is a **metered external resource**. Use it deliberately, not as a default replacement for Claude, Codex, Gemini, or the current session.

The CLI finds the API key itself. When `AI_OPENROUTER_KEY_COMMAND` is set, the key is what that shell command prints; if the command fails, the run stops with its exit code and does not fall back. Otherwise the key is `AI_OPENROUTER_KEY`, in this order: the environment, `${XDG_CONFIG_HOME:-$HOME/.config}/cli-openrouter/.env`, `${CLAUDE_SKILL_DIR}/.env`; a key the API rejects falls through to the next one. Both variables are read from the same places. `${CLAUDE_SKILL_DIR}/env.example` shows the file format. Never read the key yourself.

Never print, log, commit, or expose the key.

## When to use

Use OpenRouter when:

- the user explicitly requests `openrouter`;
- the user requests a specific model through OpenRouter;
- a primary model or integration is unavailable or out of quota;
- a simple mechanical task can be handled more cheaply by an OpenRouter model;
- comparing or testing specific OpenRouter models is itself the task;
- an independent code or architecture review is explicitly requested or routed by `workflow/references/review.md`.

Typical cheap tasks:

- rewriting or tightening existing text;
- summarizing or condensing supplied text or logs;
- classification and extraction;
- translation of fixed text;
- boilerplate generation.

Do **not** use OpenRouter merely because it is available.

Routing by model: Claude models (`opus`, `sonnet`, `haiku`, `fable`) always run through
Claude Code (`claude -p`, the subscription), never through OpenRouter. `luna` normally runs through the subscribed Codex lane; when that lane is unavailable or out of quota, Claude Code can query its OpenRouter model directly via this CLI. Any other paid model through OpenRouter is a rare
exception that needs a stated reason, unless another skill routes it here.

For complex work, keep Claude Code responsible for execution and verification. Use OpenRouter for independent analysis when explicitly requested, when the primary model is unavailable, or when the established review workflow routes a review through OpenRouter.

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

when a particular model is explicitly requested or the task requires one; choose that model from `models.toml` (below).

Find current model IDs with:

```bash
openrouter-cli models SUBSTRING
```

Do not duplicate the tier's model lists in this skill. They change over time and are maintained by the CLI.

The curated catalog lives in `models.toml`; the aliases other skills resolve with `model-id --openrouter` (`grok`, `muse`) stay in `models.json`. Review routing remains in `workflow/references/review.md`.

## Curated model selection

`models.toml` holds the owner's curated list of models, grouped by developer country and vendor, each with destination tags and an approximate cost tier. It is the first place to look whenever an OpenRouter model has to be chosen and the request does not name one: a review, a comparison, a fallback, or a task the `free` tier cannot handle. It is **not** the live provider catalog or a verified benchmark, and listing a Claude model there does not change the routing above: Claude models still run through Claude Code.

Use `openrouter-cli -m ALIAS` (the entry's table name, for example `grok`) for entries with verified IDs, or `-m provider/model` for any valid live OpenRouter ID. Entries with empty `id` are documentation only until verified and filled; do not guess IDs. Catalog aliases need Python 3.11+ (`tomllib`); on an older `python3` only the `model-id` aliases resolve.

To choose a model:

1. Keep the entries whose `destination` names the task (`code-review`, `architecture`, `reasoning`, `large-context`, `mechanical`, `quick-check`, …) and whose `id` is filled.
2. Take the lowest `cost_tier` among them, the higher `score` within a tier; step up only when the task needs it. The file's header lists preliminary picks per task; `score` is a survey opinion, weak where `score_n` is below 3.
3. Check its live price and context with `openrouter-cli models <id>`.
4. Call it by alias (`openrouter-cli -m <alias>`) and name the alias and the reason in the report.

An `id` starting with `~` follows the vendor's latest version. Respect the existing subscription-first and paid-call rules. Never automatically run every listed model.

Claude Code remains the execution harness: collect minimal safe context, call `openrouter-cli`, inspect results, and perform file edits, commands, and verification itself. Do not invoke Codex, Claude, or Gemini agent CLIs merely because a model from their provider was selected.

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

## Claude Code execution and quota fallback

Claude Code is the existing execution agent: it reads repository files, chooses relevant context, invokes tools, edits code, runs tests, and verifies outcomes. OpenRouter supplies **model responses** through `openrouter-cli`; it does not provide an agent harness or automatically apply changes.

When the Codex subscription is exhausted or its CLI is unavailable, do **not** invoke Codex merely to get a model response. Claude Code may instead call `openrouter-cli -m MODEL` with a focused question and necessary sanitized context, inspect the answer, and implement or verify changes itself. OpenRouter billing is separate from Codex subscription limits. Do not imply that a text response automatically executes edits or tools.

The model ID selects a **model**, not a harness. For example, `-m openai/...`, `-m anthropic/...`, and `-m google/...` all make direct OpenRouter API requests through the same CLI. Do not introduce `--agent`, provider-specific subcommands, or a separate `codex-openrouter` wrapper for this workflow.

If another workflow genuinely requires Codex-specific agent tools, that is a different requirement; direct OpenRouter text calls are not a drop-in replacement. Follow the requesting workflow's explicit contract rather than silently claiming agent equivalence.

## Independent review

When explicitly requested or routed by `workflow/references/review.md`, use `openrouter-cli -m MODEL` to obtain an independent review of a **focused diff or design**, not an entire repository dump. Give the model the relevant constraints and ask for concrete findings with file/line evidence. Claude Code independently validates findings against the actual code before applying changes. Do not automatically run a panel of models; model selection and review sequence belong to the workflow, not this skill.

## Model inventory

`models.json` holds only aliases used by the existing model-resolution workflow (currently `grok` and `muse`); it is not an exhaustive OpenRouter catalog. Use `openrouter-cli models [SUBSTRING]` to discover live IDs and prices. Do not copy model-quality rankings or fixed prices into this file: quality depends on evaluation tasks and cost on tokens and pricing, so the owner's estimates live only in `models.toml`.

