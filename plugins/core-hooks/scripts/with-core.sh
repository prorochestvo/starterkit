#!/usr/bin/env bash
# Hook launcher for core-hooks: runs one hook of this plugin with the core plugin's
# bin/ first on PATH.
#
# Usage (from hooks/hooks.json): with-core.sh <hook file name under hooks/>
#
# Claude Code adds a plugin's bin/ to the Bash tool's PATH but not to the PATH of hook
# subprocesses, so a hook cannot reach model-id, second-opinion.sh or the other core
# helpers by command name. This launcher finds the installed core plugin through
# ${CLAUDE_CONFIG_DIR:-$HOME/.claude}/plugins/installed_plugins.json and prepends its
# bin/ to PATH before it executes the hook with the original stdin.
#
# Dedupe: when the user settings.json in the same configuration directory registers a hook
# command that names a file with the same base name as this hook (for example a copy of
# review-commit-msg.sh under that directory's hooks/), the hook already runs from the
# settings and this launcher exits 0 without output, so the hook never runs twice.
#
# Entry choice, in order: core@starterkit before core@<other marketplace>; within one
# key, an entry whose projectPath is $CLAUDE_PROJECT_DIR (local or project scope) before
# a user-scope entry. An entry counts only when its installPath/bin is a directory.
#
# Fails open: when core is not installed, it prints one line to stderr and exits 0;
# when the hook file is not present, or python3 is missing, it exits 0 without output.
# A hook that is found runs with its own exit status.
set -u

hook="${1:-}"
root="${CLAUDE_PLUGIN_ROOT:-$(cd -P "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
target="$root/hooks/$hook"
if [ -z "$hook" ] || [ ! -f "$target" ] || [ ! -x "$target" ]; then
  exit 0
fi

command -v python3 >/dev/null 2>&1 || exit 0

registry="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/plugins/installed_plugins.json"
settings="$(dirname "$(dirname "$registry")")/settings.json"
registered="$(python3 - "$settings" "$hook" <<'PY'
import json, os, shlex, sys

settings, hook = sys.argv[1], sys.argv[2]
try:
    with open(settings, encoding="utf-8") as f:
        events = json.load(f).get("hooks", {})
except (OSError, ValueError, AttributeError):
    sys.exit(0)
if not isinstance(events, dict):
    sys.exit(0)

for groups in events.values():
    for group in groups if isinstance(groups, list) else []:
        handlers = group.get("hooks", []) if isinstance(group, dict) else []
        for handler in handlers if isinstance(handlers, list) else []:
            command = handler.get("command") if isinstance(handler, dict) else None
            if not isinstance(command, str):
                continue
            try:
                words = shlex.split(command)
            except ValueError:
                words = command.split()
            if any(os.path.basename(w) == hook for w in words):
                print("registered")
                sys.exit(0)
PY
)"
if [ -n "$registered" ]; then
  exit 0
fi

core_bin="$(python3 - "$registry" "${CLAUDE_PROJECT_DIR:-}" <<'PY'
import json, os, sys

registry, project = sys.argv[1], sys.argv[2]
try:
    with open(registry, encoding="utf-8") as f:
        plugins = json.load(f).get("plugins", {})
except (OSError, ValueError, AttributeError):
    sys.exit(0)
if not isinstance(plugins, dict):
    sys.exit(0)

keys = sorted((k for k in plugins if k.split("@", 1)[0] == "core"),
              key=lambda k: (k != "core@starterkit", k))
for key in keys:
    entries = plugins.get(key)
    if not isinstance(entries, list):
        continue
    entries = [e for e in entries if isinstance(e, dict)]
    ranked = [e for e in entries if project and e.get("projectPath") == project]
    ranked += [e for e in entries if e.get("scope") == "user"]
    for entry in ranked:
        path = os.path.join(str(entry.get("installPath", "")), "bin")
        if entry.get("installPath") and os.path.isdir(path):
            print(path)
            sys.exit(0)
PY
)"

if [ -z "$core_bin" ]; then
  echo "core-hooks: the core plugin is not installed; install core@starterkit (hook $hook skipped)" >&2
  exit 0
fi

export PATH="$core_bin:$PATH"
exec "$target"
