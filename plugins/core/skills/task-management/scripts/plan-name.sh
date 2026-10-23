#!/usr/bin/env bash
# plan-name.sh — the filename of a new plan: YYMMDD.NNNN.slug.md
#
#   plan-name.sh -t TITLE [-d PLANS_DIR]      run from the repo root
#
# YYMMDD is the UTC day the plan is created and NNNN its number. Both are fixed for
# the plan's whole life: completing or abandoning it moves the file into
# completed/ or history/ without renaming it, so the id a backlog entry or a
# commit cites never goes stale.
#
# NNNN is the highest number in use plus one, counted across plans/,
# completed/ and history/ and across every shape on disk: the current
# YYMMDD.NNNN.slug, the legacy active NNN-slug, and the legacy completed
# YYMMDD.NNNN.slug whose date was the completion day. A gap is never refilled.
set -uo pipefail

TITLE=""; DIR=""
while [ $# -gt 0 ]; do
  case "$1" in
    -t|--title|-d|--dir)
      [ $# -ge 2 ] || { printf 'missing value for %s\n' "$1" >&2; exit 2; } ;;
  esac
  case "$1" in
    -t|--title) TITLE="${2:-}"; shift 2 ;;
    -d|--dir)   DIR="${2:-}"; shift 2 ;;
    -h|--help)  sed -n '2,14p' "$0"; exit 0 ;;
    *) printf 'unknown argument: %s\n' "$1" >&2; exit 2 ;;
  esac
done

[ -n "$TITLE" ] || { echo 'plan-name: -t TITLE is required' >&2; exit 2; }
# A repo not yet migrated keeps a root plans/ tree; numbering both would collide.
if [ -z "$DIR" ] && [ -d plans ]; then
  echo 'plan-name: a root plans/ exists; migrate it with pipeline:onboard first' >&2
  exit 2
fi
if [ -z "$DIR" ] && [ ! -d .agents/plans ]; then
  echo 'plan-name: no .agents/plans/ here; run from the repo root or pass -d' >&2
  exit 2
fi

python3 - "$TITLE" "${DIR:-.agents/plans}" <<'PY'
import datetime, os, re, sys
title, root = sys.argv[1], sys.argv[2]
slug = re.sub(r"[^a-z0-9]+", "-", title.lower()).strip("-")[:60].strip("-") or "plan"
used = set()
for sub in ("", "completed", "history"):
    path = os.path.join(root, sub)
    if not os.path.isdir(path):
        continue
    for name in os.listdir(path):
        m = re.match(r"^\d{6}\.(\d{4})\.", name) or re.match(r"^(\d{3})-", name)
        if m:
            used.add(int(m.group(1)))
print("%s.%04d.%s.md" % (datetime.datetime.now(datetime.timezone.utc).strftime("%y%m%d"), max(used, default=0) + 1, slug))
PY
