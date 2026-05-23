#!/usr/bin/env bash
# Install a Claude Code starter into a target project.
#
# Usage:
#   ./install.sh <stack> <target-dir>
#
#   <stack>       — flutter | golang | scala
#   <target-dir>  — destination project root (must exist)
#
# Copies CLAUDE.md, .claude/ (agents, commands, settings.json, agent-memory
# skeleton, prompts), and the plans/ directory layout into the target.
# Refuses to overwrite an existing CLAUDE.md or .claude/ unless --force is
# passed.

set -euo pipefail

STARTER_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

usage() {
  cat <<EOF
Usage: $0 <flutter|golang|scala> <target-dir> [--force]

  flutter | golang | scala  — which stack template to install
  <target-dir>              — destination project root (must exist)
  --force                   — overwrite existing CLAUDE.md / .claude/
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
  flutter|golang|scala) ;;
  *) echo "error: unknown stack '$STACK' (expected flutter, golang, or scala)" >&2; usage; exit 1 ;;
esac

if [[ ! -d "$TARGET" ]]; then
  echo "error: target directory '$TARGET' does not exist" >&2
  exit 1
fi

SRC="$STARTER_ROOT/$STACK"
if [[ ! -d "$SRC" ]]; then
  echo "error: source stack directory '$SRC' missing — corrupt checkout?" >&2
  exit 1
fi

if [[ -e "$TARGET/CLAUDE.md" && "$FORCE" != "--force" ]]; then
  echo "error: '$TARGET/CLAUDE.md' already exists. Re-run with --force to overwrite." >&2
  exit 1
fi
if [[ -e "$TARGET/.claude" && "$FORCE" != "--force" ]]; then
  echo "error: '$TARGET/.claude' already exists. Re-run with --force to overwrite." >&2
  exit 1
fi

echo "Installing $STACK starter into $TARGET ..."

cp "$SRC/CLAUDE.md" "$TARGET/CLAUDE.md"
echo "  + CLAUDE.md"

cp -R "$SRC/.claude" "$TARGET/.claude"
echo "  + .claude/ (agents, commands, settings.json, agent-memory, prompts)"

mkdir -p "$TARGET/plans/completed" "$TARGET/plans/history"
touch "$TARGET/plans/completed/.gitkeep" "$TARGET/plans/history/.gitkeep"
echo "  + plans/ (active, completed/, history/)"

cat <<EOF

Done. Next steps:
  1. cd $TARGET
  2. Open CLAUDE.md and replace every <...> placeholder with real project values.
  3. Review .claude/settings.json — adjust the permission allowlist for your project.
  4. Start a Claude Code session in the repo; subagents and slash commands are picked up automatically.

Tip: use /new-plan <slug> to create your first plan file.
EOF
