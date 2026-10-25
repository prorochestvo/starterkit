#!/usr/bin/env bash
# backlog-triage.sh — two moments in a backlog entry's life, deliberately split.
#
#   --name   -t TITLE -p H|M|L [-P PLAN] [-d DIR]   instant, no model call
#            PLAN: the plan the entry came from - its id (YYMMDD.NNNN, legacy NNN)
#            or its filename; the name then starts with '<id>-'
#   --gate   -f DRAFT [-d DIR]              is the entry needed at all? before it is written
#   --list   [-d DIR]                       open entries, one line each, files unread
#   --stale  [N] [-d DIR]                   open entries, longest ungroomed first (N: first N)
#   --assess -f FILE                        external judgement, before work starts
#
# WHY THE SPLIT. An entry is captured the moment a thought surfaces - one file,
# then back to the task. Putting a 60-second model call there trades the one
# property that makes the backlog work for an opinion nobody needs yet, and
# spends a paid quota per entry. The priority at capture is Claude's own
# provisional call; the external assessment happens when the entry is about to
# become work, which is the moment the answer actually changes something. Fewer
# entries reach that point than are written, so it is cheaper as well as better.
#
# THE GATE. Before an entry is written, sol and opus judge whether it is needed
# and whether an open entry already covers it; fable decides when they disagree
# or one is missing. The caller runs it in the background so the task goes on.
#
# FAIL-OPEN. --gate with no decision says create. --assess never blocks work:
# with no verdict it says so and keeps the entry's current priority.
set -uo pipefail

MODE=""; TITLE=""; PRIORITY=""; DIR=""; FILE=""; PLAN=""; ESCALATE=0; COUNT=0
while [ $# -gt 0 ]; do
  case "$1" in
    -t|--title|-p|--priority|-d|--dir|-f|--file|-P|--plan)
      [ $# -ge 2 ] || { printf 'missing value for %s\n' "$1" >&2; exit 2; } ;;
  esac
  case "$1" in
    --name|--assess|--gate|--list) MODE="${1#--}"; shift ;;
    --stale)         MODE=stale; shift
                     case "${1:-}" in ""|*[!0-9]*) ;; *) COUNT="$1"; shift ;; esac ;;
    -t|--title)      TITLE="${2:-}"; shift 2 ;;
    -p|--priority)   PRIORITY="$(printf '%s' "${2:-}" | tr '[:lower:]' '[:upper:]' | cut -c1)"; shift 2 ;;
    -d|--dir)        DIR="${2:-}"; shift 2 ;;
    -P|--plan)       PLAN="${2:-}"; shift 2 ;;
    -f|--file)       FILE="${2:-}"; shift 2 ;;
    --escalate)      ESCALATE=1; shift ;;
    -h|--help)       sed -n '2,26p' "$0"; exit 0 ;;
    *) printf 'unknown argument: %s\n' "$1" >&2; exit 2 ;;
  esac
done

# model-id and openrouter-cli are commands on PATH. openrouter-cli is the tiered client;
# bin/openrouter.sh is a subcommand shim that takes no tier and silently fails a `-t cheap` call.
OR="openrouter-cli"

# ---------------------------------------------------------------- --name
if [ "$MODE" = name ]; then
  [ -n "$TITLE" ] || { echo 'backlog-triage --name: -t TITLE is required' >&2; exit 2; }
  case "$PRIORITY" in H|M|L) ;; *) echo 'backlog-triage --name: -p must be H, M or L' >&2; exit 2 ;; esac
  # A repo not yet migrated to .agents/ keeps its root plans/ tree until onboard
  # moves it. Both trees at once would number two backlogs independently.
  if [ -d plans ] && [ -d .agents/plans ]; then
    echo 'backlog-triage --name: both plans/ and .agents/plans/ exist; finish the move with pipeline:onboard' >&2
    exit 2
  fi
  default_dir=.agents/plans/backlog
  if [ -z "$DIR" ] && [ ! -d .agents/plans ] && [ ! -d plans ]; then
    echo 'backlog-triage --name: no .agents/plans/ here; run from the repo root or pass -d' >&2
    exit 2
  fi
  [ -d plans ] && default_dir=plans/backlog
  python3 - "$TITLE" "$PRIORITY" "${DIR:-$default_dir}" "$PLAN" <<'PY'
import datetime, os, re, sys
title, priority, dirpath, plan = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4]
# The origin plan's id: YYMMDD.NNNN, or a legacy active plan's NNN.
prefix = ""
if plan:
    m = re.match(r"^(?:.*/)?(\d{6}\.\d{4}|\d{3})(?:[.-]|$)", plan)
    if not m:
        sys.exit("backlog-triage --name: -P must be a plan id (YYMMDD.NNNN or NNN) or a plan filename")
    prefix = m.group(1) + "-"
slug = re.sub(r"[^a-z0-9]+", "-", title.lower()).strip("-")[:60].strip("-") or "entry"
# The next index follows the highest present, so the gap an accepted (deleted)
# entry leaves is never refilled; history/ and any other subdirectory count, and
# both the old YYMMDD.NNNN and the new YYMMDD.P.NNNN shapes count, so an
# existing backlog keeps its numbering.
used = set()
for _, _, names in os.walk(dirpath):
    for n in names:
        m = re.match(r"^(?:(?:\d{6}\.\d{4}|\d{3})-)?\d{6}\.(?:[HML]\.)?(\d{4})\.", n)
        if m:
            used.add(int(m.group(1)))
idx = max(used, default=0) + 1
print("%s%s.%s.%04d.%s.md" % (prefix, datetime.datetime.now(datetime.timezone.utc).strftime("%y%m%d"), priority, idx, slug))
PY
  exit $?
fi

backlog_dir() {
  if [ -n "$DIR" ]; then echo "$DIR"; elif [ -d plans ]; then echo plans/backlog; else echo .agents/plans/backlog; fi
}

# open_list: one line per open entry, top level only; history/ is never read.
# The entry being gated is left out, so an existing entry is not its own duplicate.
open_list() {
  local d f; d="$(backlog_dir)"
  [ -d "$d" ] || return 0
  for f in "$d"/*.md; do
    [ -e "$f" ] || continue
    [ -n "$FILE" ] && [ "$(basename "$f")" = "$(basename "$FILE")" ] && continue
    printf '%s  %s\n' "$(basename "$f" .md)" "$(sed -n '1s/^# *//p' "$f")"
  done
}

# bounded SECS CMD...: run CMD, kill it after SECS; macOS has no timeout(1).
# The explicit <&0 keeps the caller's stdin: a background job would get /dev/null.
bounded() {
  local secs="$1" pid guard rc; shift
  "$@" <&0 & pid=$!
  ( sleep "$secs"; kill "$pid" 2>/dev/null ) & guard=$!
  wait "$pid" 2>/dev/null; rc=$?
  kill "$guard" 2>/dev/null; wait "$guard" 2>/dev/null
  return "$rc"
}

# ---------------------------------------------------------------- --list
if [ "$MODE" = list ]; then open_list; exit 0; fi

# ---------------------------------------------------------------- --stale
# Grooming order: the entry groomed longest ago comes first. An entry carries
# "- groomed: YYYY-MM-DD HH:MMZ" once a grooming pass kept it; one never groomed
# counts from the date in its name. Prints "<groomed or never>  <name>  <title>".
if [ "$MODE" = stale ]; then
  d="$(backlog_dir)"
  [ -d "$d" ] || exit 0
  python3 - "$d" "$COUNT" <<'PY'
import os, re, sys
d, count = sys.argv[1], int(sys.argv[2])
rows = []
for n in sorted(os.listdir(d)):
    p = os.path.join(d, n)
    if not n.endswith(".md") or not os.path.isfile(p):
        continue
    with open(p, encoding="utf-8") as fh:
        text = fh.read()
    title = next((l.lstrip("#").strip() for l in text.splitlines() if l.startswith("#")), "")
    m = re.search(r"^- groomed: (\d{4})-(\d{2})-(\d{2}) (\d{2}):(\d{2})Z", text, re.M)
    if m:
        key = shown = "".join(m.groups())
    else:
        r = re.match(r"^(?:(?:\d{6}\.\d{4}|\d{3})-)?(\d{6})\.", n)
        key, shown = ("20" + r.group(1) + "0000") if r else "0" * 12, "never"
    rows.append((key, n[:-3], shown, title))
rows.sort()
for _, name, shown, title in rows[:count or None]:
    print("%-12s  %s  %s" % (shown, name, title))
PY
  exit $?
fi

# ---------------------------------------------------------------- --gate
if [ "$MODE" = gate ]; then
  [ -n "$FILE" ] && [ -r "$FILE" ] || { echo 'backlog-triage --gate: -f DRAFT must be readable' >&2; exit 2; }
  GATE_PROMPT='You decide whether a draft backlog entry should be written at all.
It is worth writing when it names a concrete problem, risk, or decision that is
not recorded yet and that the current task does not settle. It is NOT worth
writing when it is already handled, restates how the code works, is speculation
with no failure it prevents, is too vague to act on, belongs in the current task,
or duplicates one of the open entries listed below.

Answer with ONE line of JSON and nothing else:
{"create":true,"duplicate_of":null,"reason":"<at most 25 words>"}
duplicate_of is the name of the open entry it duplicates, or null.'
  gparse() { python3 -c '
import json, re, sys
m = re.search(r"\{.*\}", sys.stdin.read(), re.S)
if not m: sys.exit(1)
try: d = json.loads(m.group(0))
except Exception: sys.exit(1)
if "create" not in d: sys.exit(1)
print(json.dumps({"create": bool(d["create"]), "duplicate_of": d.get("duplicate_of") or None,
                  "reason": str(d.get("reason",""))[:200]}))
'; }
  tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
  printf '%s\n\n--- OPEN ENTRIES ---\n%s\n\n--- DRAFT ---\n%s\n' \
    "$GATE_PROMPT" "$(open_list)" "$(cat "$FILE")" > "$tmp/in"
  # sol and opus vote in parallel, each bounded.
  if command -v codex >/dev/null 2>&1; then
    ( bounded 240 codex exec --ephemeral --skip-git-repo-check --ignore-user-config -s read-only \
        -m "$(model-id sol)" -o "$tmp/sol.raw" "$(cat "$tmp/in")" </dev/null >/dev/null 2>&1
      gparse < "$tmp/sol.raw" > "$tmp/sol" 2>/dev/null ) &
  fi
  if command -v claude >/dev/null 2>&1; then
    ( bounded 240 claude -p --model opus < "$tmp/in" > "$tmp/opus.raw" 2>/dev/null
      gparse < "$tmp/opus.raw" > "$tmp/opus" 2>/dev/null ) &
  fi
  wait
  sol="$(cat "$tmp/sol" 2>/dev/null)"; opus="$(cat "$tmp/opus" 2>/dev/null)"
  agree=0
  if [ -n "$sol" ] && [ -n "$opus" ]; then
    vote() { python3 -c 'import json,sys;print(json.load(sys.stdin)["create"])'; }
    [ "$(printf '%s' "$sol" | vote)" = "$(printf '%s' "$opus" | vote)" ] && agree=1
  fi
  # fable decides a split or a missing vote, seeing both answers.
  fable=""
  if [ "$agree" = 0 ] && command -v claude >/dev/null 2>&1; then
    { cat "$tmp/in"
      printf '\n--- EARLIER VOTES (they disagree or one is missing; you decide) ---\nsol: %s\nopus: %s\n' \
        "${sol:-no answer}" "${opus:-no answer}"
    } > "$tmp/fin"
    bounded 300 claude -p --model fable < "$tmp/fin" > "$tmp/fable.raw" 2>/dev/null
    fable="$(gparse < "$tmp/fable.raw" 2>/dev/null)" || fable=""
  fi
  python3 - "${sol:-}" "${opus:-}" "${fable:-}" "$agree" "$(basename "$FILE" .md)" <<'PY'
import json, sys
sol, opus, fable = [json.loads(v) if v else None for v in sys.argv[1:4]]
# A vote that calls the entry a duplicate of itself is a misread, not a verdict.
for v in (sol, opus, fable):
    if v and not v["create"] and (v["duplicate_of"] or "").removesuffix(".md") == sys.argv[5]:
        v.update(create=True, duplicate_of=None, reason="self-duplicate vote ignored: " + v["reason"])
if sys.argv[4] == "1":
    create, by = sol["create"], "sol+opus"
    dup = sol["duplicate_of"] or opus["duplicate_of"]
    reason = " | ".join(x["reason"] for x in (sol, opus) if x["reason"])
elif fable:
    create, by, dup, reason = fable["create"], "fable", fable["duplicate_of"], fable["reason"]
elif sol or opus:
    # fable did not answer: the one vote that came in decides.
    one, by = (sol, "sol") if sol else (opus, "opus")
    create, dup, reason = one["create"], one["duplicate_of"], one["reason"]
else:
    # No decision: write the entry. An outage must never swallow a question.
    create, by, dup, reason = True, "none", None, "no decision - the entry is written"
print(json.dumps({"create": create, "duplicate_of": None if create else dup,
                  "reason": reason, "decided_by": by,
                  "votes": {"sol": sol, "opus": opus, "fable": fable}}))
PY
  exit 0
fi

# ---------------------------------------------------------------- --assess
[ "$MODE" = assess ] || { echo 'backlog-triage: pass --name, --gate, --list, --stale or --assess' >&2; exit 2; }
[ -n "$FILE" ] && [ -r "$FILE" ] || { echo 'backlog-triage --assess: -f FILE must be readable' >&2; exit 2; }

CURRENT="$(basename "$FILE" | sed -nE 's/^(([0-9]{6}\.[0-9]{4}|[0-9]{3})-)?[0-9]{6}\.([HML])\..*/\3/p')"
[ -n "$CURRENT" ] || CURRENT="M"

PROMPT='You are judging one backlog entry that is about to be taken into work.
Decide two things from the entry itself.

1. WORTH: is this a real problem or a necessary task? Reply false when it is
   already solved, restates how the code works, is speculation with no failure
   it prevents, or is too vague to act on. Reply true otherwise.
2. PRIORITY: H = correctness, security, data loss, or already breaking.
   M = a real defect or gap that is not urgent. L = cleanup, consistency,
   nice-to-have.

Answer with ONE line of JSON and nothing else:
{"worth":true,"priority":"H","reason":"<at most 20 words>"}'

material() { printf '%s\n\n--- ENTRY ---\n%s\n' "$PROMPT" "$(cat "$FILE")"; }

parse() { python3 -c '
import json, re, sys
m = re.search(r"\{.*?\}", sys.stdin.read(), re.S)
if not m: sys.exit(1)
try: d = json.loads(m.group(0))
except Exception: sys.exit(1)
p = str(d.get("priority","")).upper()[:1]
if p not in ("H","M","L"): sys.exit(1)
print(json.dumps({"worth": bool(d.get("worth")), "priority": p,
                  "reason": str(d.get("reason",""))[:140]}))
'; }

v1=""; command -v "$OR" >/dev/null 2>&1 && v1="$(material | "$OR" -t cheap 2>/dev/null | parse)" || true
by="openrouter"; [ -n "$v1" ] || by="none"

# The paid lane runs when the cheap one is absent, calls it H, or on request.
need2=0
[ "$ESCALATE" = 1 ] && need2=1
[ -z "$v1" ] && need2=1
[ -n "$v1" ] && [ "$(printf '%s' "$v1" | python3 -c 'import json,sys;print(json.load(sys.stdin)["priority"])')" = H ] && need2=1

v2=""
if [ "$need2" = 1 ] && command -v codex >/dev/null 2>&1; then
  sol_out="$(mktemp)"
  material | codex exec --ephemeral --skip-git-repo-check --ignore-user-config -s read-only \
    -m "$(model-id sol)" -c model_reasoning_effort="low" -o "$sol_out" - >/dev/null 2>&1 || true
  v2="$(parse < "$sol_out")" || v2=""
  rm -f "$sol_out"
  [ -n "$v2" ] && { [ "$by" = none ] && by="sol" || by="openrouter+sol"; }
fi

python3 - "$FILE" "$CURRENT" "$by" "${v1:-}" "${v2:-}" <<'PY'
import json, os, re, sys
path, current, by = sys.argv[1], sys.argv[2], sys.argv[3]
votes = [json.loads(v) for v in sys.argv[4:] if v]
rank = {"H": 3, "M": 2, "L": 1}
if votes:
    worth = all(v["worth"] for v in votes)
    # A disagreement on urgency resolves upward: under-rating a real defect
    # costs more than looking at an M that turned out to be an L.
    priority = max((v["priority"] for v in votes), key=lambda p: rank[p])
    reason = " | ".join(v["reason"] for v in votes if v["reason"])
else:
    worth, priority, reason = True, current, "no reviewer answered - priority unchanged"
base = os.path.basename(path)
renamed = re.sub(r"^((?:(?:\d{6}\.\d{4}|\d{3})-)?\d{6})\.(?:[HML]\.)?(\d{4})\.", r"\1.%s.\2." % priority, base)
# A rejected entry stays put with its reason and never becomes work, so its
# priority stops mattering; renaming it would be churn in the git history.
if not worth or renamed == base:
    renamed = None
print(json.dumps({
    "worth": worth, "priority": priority, "was": current, "reason": reason,
    "rename_to": renamed, "assessed_by": by,
}))
PY
