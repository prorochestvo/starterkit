# cli-openrouter

Part of the `core` plugin. Catalog aliases from `models.toml` need Python 3.11+ (`tomllib`);
explicit IDs and the `model-id` aliases in `models.json` work on older Python.

- `openrouter-cli -m grok "..."` resolves the curated alias.
- `openrouter-cli -m provider/model "..."` uses any explicit model ID.
- `openrouter-cli models QUERY` checks the live catalog.
- Fill empty IDs in `models.toml` only after checking the live catalog.
- `models.toml` cost/quality values are owner-provided estimates, not API prices.
- No `codex-openrouter` script: Claude Code remains responsible for agentic execution.
