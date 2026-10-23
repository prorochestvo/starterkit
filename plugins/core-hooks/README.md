# core-hooks

Opt-in hooks on top of [`core`](../core/README.md). They are a separate plugin because two
of them send session data to paid external models; installing `core` for its skills does
not enable them. `core-hooks` declares `core` as a dependency, and neither `install.sh`
nor the project templates enable `core-hooks`.

## Hooks

| Hook | Event | What it does |
|------|-------|--------------|
| `review-commit-msg.sh` | `PreToolUse` `Bash`, on `git commit` (timeout 150 s) | Reviews the commit message against the commit conventions when the commit lands on an integration branch (`main`, `stage`, `prod`, `dev`). A rejected message blocks the commit and the reasons go back to the agent; a reviewer failure lets the commit through. Commits on other branches are not reviewed. |
| `question-quorum.py` | `PreToolUse` `AskUserQuestion` (timeout 180 s) | Before a multiple-choice question reaches you, a panel of external models answers it. When the panel agrees on every question in the batch, the question is not shown and the agreed answers are applied without asking you. Any disagreement, or a question the panel cannot answer, reaches you unchanged. |
| `userprompt-remark-marker.py` | `UserPromptSubmit` (timeout 5 s) | When a prompt starts with `~wtf` or `~ok`, adds an instruction to load the `skill-tuner` skill. Sends nothing outside the session. |

## Data sent to external services

- Commit messages on integration branches, and the multiple-choice questions the session
  asks together with their options, are sent to OpenAI (through the `codex` client),
  Anthropic (through a separate `claude -p` call) and OpenRouter (through `openrouter-cli`).
- Answers the quorum agrees on are applied without asking you.

Each hook runs through `scripts/with-core.sh`, which finds the installed `core` plugin in
`${CLAUDE_CONFIG_DIR:-$HOME/.claude}/plugins/installed_plugins.json` and puts its `bin/` on
the hook's `PATH`. When `core` is not installed, the hook prints one line naming
`core@starterkit` and lets the action through.

When the user `settings.json` in the same configuration directory already registers a hook
command that names a file with the same base name (for example a copy of
`review-commit-msg.sh` wired in the user settings), `with-core.sh` exits without running the
plugin's copy, so the hook does not run twice. `scripts/test-with-core.sh` tests these cases.

## Disabling

- For yourself: `claude plugin disable core-hooks@starterkit` (or `/plugin` in a session),
  or `claude plugin uninstall core-hooks@starterkit`.
- For one project: set `"core-hooks@starterkit": false` under `enabledPlugins` in the
  project's `.claude/settings.json`.

The change applies to sessions started after it.
