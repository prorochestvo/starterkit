#!/usr/bin/env bash
# backlog-triage.sh - runs the task-management skill's scripts/backlog-triage.sh,
# so callers can use the command name on PATH.
# The target is found relative to this file's real path (bin/ next to skills/), which
# holds both in the configuration checkout and in the core plugin; stock macOS has no realpath.
set -euo pipefail
src="${BASH_SOURCE[0]}"
while [ -L "$src" ]; do
  dir="$(cd -P "$(dirname "$src")" && pwd)"
  src="$(readlink "$src")"
  case "$src" in /*) ;; *) src="$dir/$src" ;; esac
done
here="$(cd -P "$(dirname "$src")" && pwd)"
exec "$here/../skills/task-management/scripts/backlog-triage.sh" "$@"
