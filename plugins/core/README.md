# core

Shared agent tooling that the other starterkit plugins build on: skills for the plan and
backlog lifecycle, the development workflow, git and GitHub rules, engineering contracts,
instruction writing, and skill maintenance; clients for external models; the
second-opinion review flow; and the `code-standards-auditor` agent.

`pipeline` and `core-hooks` need `core`. Both declare it as a dependency, so installing
either of them installs `core` as well; disabling or uninstalling `core` afterwards breaks
their calls into it.

## Contents

| Kind | Items |
|------|-------|
| Skills | `task-management`, `workflow`, `writing-instructions`, `cli-git`, `cli-github`, `common-contracts`, `skill-tuner`, `skill-incubator`, `ai-claude`, `ai-codex`, `ai-gemini`, `cli-openrouter`, `cli-cloudflare` |
| Helpers (`bin/`, on the Bash tool's `PATH` while the plugin is enabled) | `model-id`, `second-opinion.sh`, `codex-limits.py`, `plan-name.sh`, `backlog-triage.sh`, `openrouter-cli`, `codex-openrouter` |
| Agents | `code-standards-auditor` |

Skills are listed as `core:<name>`. Instructions in this and the other starterkit plugins
name them by the bare name (`task-management`), which resolves to `core:<name>` when no
skill of that name is installed outside the plugin.

These files are published from the maintainer's own configuration by an export script. A
direct edit in this directory stops the next export until the change is carried back to
that source, so propose changes through an issue or a pull request that says so.

## Data sent to external services

- `second-opinion.sh` sends the material it reviews (a diff, or the full files with
  `--full` or `--target files:...`) to external models: OpenRouter by default, whose tier
  aliases include OpenAI's Codex-family GPT models, and Google's Gemini through the `agy`
  client when `--model` is given. Nothing is sent unless the script is run.
- `openrouter-cli` and `codex-openrouter` send their prompts to OpenRouter; the `ai-codex`,
  `ai-gemini` and `ai-claude` skills call the `codex`, `agy` and `claude` command-line
  clients, which send their prompts to OpenAI, Google and Anthropic.
- `cli-cloudflare` acts on the Cloudflare account its token belongs to.

## Keys

Keys are never stored inside the plugin: the plugin cache is replaced on every version
update. `openrouter-cli`, `codex-openrouter` and `cli-cloudflare`'s `cf-token-run` look a key
up in this order:

1. the environment variable;
2. `${XDG_CONFIG_HOME:-$HOME/.config}/<tool>/.env`;
3. a `.env` file in the skill's own directory (present only in a configuration that keeps
   the skills outside the plugin);
4. on macOS, the login keychain.

Each skill's `env.example` names the variables and the exact `<tool>` directory.
