#!/usr/bin/env bash
# Scaffold a new project with the starterkit templates.
#
# Usage:
#   ./install.sh <stack> <target-dir> [--force]
#
#   <stack>       — go | flutter
#   <target-dir>  — destination project root (must exist)
#   --force       — overwrite an existing AGENTS.md / CLAUDE.md / .claude/settings.json
#
# Copies the stack's AGENTS.md template (CLAUDE.md links to it) and .claude/settings.json (permission
# allowlist + starterkit marketplace wiring + enabled plugins) and creates the
# .agents/ directory layout. Agents, skills, and doctrine are NOT copied — they
# ship via the plugin marketplace and update centrally.

set -euo pipefail

STARTER_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

usage() {
  cat <<EOF
Usage: $0 <go|flutter> <target-dir> [--force]
EOF
}

if [[ $# -lt 2 ]]; then
  usage
  exit 1
fi

STACK="$1"
TARGET="$2"
FORCE="${3:-}"

case "$STACK" in
  go|flutter) ;;
  *) echo "error: unknown stack '$STACK' (expected go or flutter)" >&2; usage; exit 1 ;;
esac

if [[ ! -d "$TARGET" ]]; then
  echo "error: target directory '$TARGET' does not exist" >&2
  exit 1
fi

SRC="$STARTER_ROOT/templates/$STACK"
if [[ ! -d "$SRC" ]]; then
  echo "error: template directory '$SRC' missing — corrupt checkout?" >&2
  exit 1
fi

for f in AGENTS.md CLAUDE.md; do
  if [[ -e "$TARGET/$f" || -L "$TARGET/$f" ]] && [[ "$FORCE" != "--force" ]]; then
    echo "error: '$TARGET/$f' already exists. Re-run with --force to overwrite." >&2
    exit 1
  fi
done
if [[ -e "$TARGET/.claude/settings.json" && "$FORCE" != "--force" ]]; then
  echo "error: '$TARGET/.claude/settings.json' already exists. Re-run with --force to overwrite." >&2
  exit 1
fi

echo "Scaffolding $STACK project in $TARGET ..."

# One instruction file for every agent: Codex reads AGENTS.md, Claude Code
# reads CLAUDE.md, and the link keeps the two from drifting apart.
cp "$SRC/AGENTS.md" "$TARGET/AGENTS.md"
rm -f "$TARGET/CLAUDE.md"
ln -s AGENTS.md "$TARGET/CLAUDE.md"
echo "  + AGENTS.md, CLAUDE.md -> AGENTS.md"

mkdir -p "$TARGET/.claude"
# Assemble settings.json: wiring template + canonical permission fragments.
# The fragments in plugins/pipeline/skills/sync-permissions/ are the single
# source of truth; the pipeline:sync-permissions skill re-merges them later.
FRAGMENTS="$STARTER_ROOT/plugins/pipeline/skills/sync-permissions"
python3 - "$SRC/settings.json" "$FRAGMENTS/core.json" "$FRAGMENTS/stack-$STACK.json" "$TARGET/.claude/settings.json" <<'PY'
import json, sys
wiring, core, stack, out = sys.argv[1:5]
settings = json.load(open(wiring))
perms = {"allow": [], "deny": []}
for path in (core, stack):
    frag = json.load(open(path))
    for key in perms:
        perms[key] += [e for e in frag.get(key, []) if e not in perms[key]]
settings["permissions"] = perms
json.dump(settings, open(out, "w"), indent=2)
open(out, "a").write("\n")
PY
echo "  + .claude/settings.json (marketplace wiring + canonical permissions)"

# A legacy root plans/ is left for onboard to move with history; a fresh
# .agents/plans/ next to it would start a second, colliding numbering.
if [ -d "$TARGET/plans" ]; then
  echo "  ! legacy plans/ found: run /pipeline:onboard to move it to .agents/plans/"
else
  for dir in plans/completed plans/history plans/backlog specs scripts; do
    mkdir -p "$TARGET/.agents/$dir"
    touch "$TARGET/.agents/$dir/.gitkeep"
  done
  echo "  + .agents/ (plans/{completed,history,backlog}, specs, scripts)"
fi

cat <<EOF

Done. Next steps:
  1. cd $TARGET && claude
  2. Approve the starterkit marketplace / plugin installation when prompted.
     (If no prompt appears: /plugin marketplace add prorochestvo/starterkit
      then /plugin install pipeline@starterkit stack-$STACK@starterkit knowledge@starterkit)
  3. Run /pipeline:onboard — it verifies the wiring and walks you through
     filling the AGENTS.md placeholders.
  4. Use the pipeline:new-plan skill to create your first plan.

Updating later: /plugin marketplace update starterkit — every project picks up
the new agents and skills without re-running this script.
EOF
