# Install skill-incubator

Requires Python 3 available as `python3` on PATH (macOS/Linux). No pip dependencies or compilation.

1. Install the `skill-incubator` directory as a personal skill in the `skills/` directory of the Claude Code configuration, or through the `core` plugin, which ships it.
2. From the skill directory, check that `scripts/incubator list` works.
3. Add the short rule from `GLOBAL-CLAUDE-SNIPPET.md` to the global `CLAUDE.md` **only after reviewing and approving the change**.
4. The state directory `${CLAUDE_CONFIG_DIR:-$HOME/.claude}/runtime-state/skills/skill-incubator/` is created automatically on first write. It is separate from the skill so updates do not erase history.

The CLI provides persistence and bookkeeping. Claude supplies semantic matching, procedure authoring, execution, review, and permission checks. Neither the CLI nor the global rule can guarantee recognition of every repetition in unrelated sessions.

For testing without changing real state, run from the skill directory:

```bash
INCUBATOR_HOME="$(mktemp -d)" scripts/incubator list
```

Do not commit the state directory to a repository or store secrets in observations.
