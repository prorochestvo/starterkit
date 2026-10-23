#!/usr/bin/env bash
# Second-opinion review flow.
#
# Sends a change to reviewers outside the Anthropic family — by default OpenRouter
# models picked by --tier, optionally agy models — and
# merges their verdicts into one ranked report, marking which findings more than
# one reviewer arrived at independently.
#
# The reviewers get exactly the material assembled here and nothing else: no
# workspace, no shell, no file access. That is deliberate. agy can be given the
# repo with --add-dir, but its read path goes through its command tool, so
# "let the reviewer read the code" means "give an autonomous agent a shell in
# your repository". Context is cheaper to assemble than that is to trust; use
# --full when the diff alone is too thin to judge.
set -euo pipefail

# This file's real directory, so a link on PATH still finds the sibling helpers
# (stock macOS has no realpath).
src="${BASH_SOURCE[0]}"
while [ -L "$src" ]; do
  dir="$(cd -P "$(dirname "$src")" && pwd)"
  src="$(readlink "$src")"
  case "$src" in /*) ;; *) src="$dir/$src" ;; esac
done
BIN="$(cd -P "$(dirname "$src")" && pwd)"
unset src dir
SCHEMA="$BIN/second-opinion-schema.json"
NORM_SCHEMA="$BIN/second-opinion-normalize-schema.json"
MERGE="$BIN/second-opinion-merge.py"
# openrouter-cli, not bin/openrouter.sh: it is the client whose key is configured, and it
# can ask for reasoning, which gemini-4-argon requires (it answers 400 without).
OPENROUTER="$BIN/openrouter-cli"

TARGET="working"
QUESTION=""
REPO=""
OUT=""
FULL=0
KEEP=0
TIER=2
TIMEOUT="300s"
ALLOW_SECRETS=0
MAX_BYTES=$((512 * 1024))
AGY_MODELS=()
OR_MODELS=()

# Schema enforcement is a per-model courtesy, not a guarantee: Gemini honours
# --json-schema, GPT-OSS answers in a markdown table regardless. Rather than
# restrict the roster to well-behaved models, prose answers get a second cheap
# pass that transcribes them into the schema without judging them.
NORMALIZER="${SECOND_OPINION_NORMALIZER:-$("$BIN/model-id" g-flash)-medium}"

die() { printf 'second-opinion: %s\n' "$*" >&2; exit 1; }
note() { printf '%s\n' "$*" >&2; }

usage() {
  cat <<'USAGE'
second-opinion.sh — have non-Anthropic reviewers critique a change

  -t, --target SPEC   what to review (default: working)
        working         uncommitted changes to tracked files (git diff HEAD)
        staged          git diff --cached
        branch[:BASE]   git diff BASE...HEAD, BASE defaults to main
        commit:REF      git show REF
        files:A,B,C     full contents of the listed files
        -               read the material from stdin

  -m, --model MODEL   agy reviewer, repeatable (default: none)
      --or MODEL      OpenRouter reviewer, repeatable, through openrouter-cli at high reasoning
      --tier N        the escalation step of a contested call, used when neither -m nor --or
                      is given (default 2):
                        2  sol and opus disagree: g-pro and grok
                        3  high cost of error (security, architecture, R# rules): adds muse
                        4  still ambiguous after 3: adds astra; ask fable through
                           claude -p yourself, it is in the Anthropic family this flow excludes
      --list-models   print the agy roster and exit

  -q, --question T    what to focus on, or the claim to check; @file to read it from a file
      --full          append the current full contents of every file the diff touches
  -C, --repo DIR      repository root (default: git toplevel of the working directory)

  -o, --out FILE      merged JSON report (default: alongside the run directory)
      --timeout DUR   per-reviewer timeout (default 300s)
      --keep          keep the per-reviewer raw output directory
      --allow-secrets skip the credential scan on the outgoing material

Reviewers outside your machine see the material. The credential scan is a
backstop, not a guarantee: check what you are sending.
USAGE
}

while [ $# -gt 0 ]; do
  case "$1" in
    -t|--target) TARGET="$2"; shift 2 ;;
    -m|--model) AGY_MODELS+=("$2"); shift 2 ;;
    --or) OR_MODELS+=("$2"); shift 2 ;;
    --tier) TIER="$2"; shift 2 ;;
    -q|--question) QUESTION="$2"; shift 2 ;;
    -C|--repo) REPO="$2"; shift 2 ;;
    -o|--out) OUT="$2"; shift 2 ;;
    --timeout) TIMEOUT="$2"; shift 2 ;;
    --full) FULL=1; shift ;;
    --keep) KEEP=1; shift ;;
    --allow-secrets) ALLOW_SECRETS=1; shift ;;
    --list-models) agy models </dev/null; exit 0 ;;
    -h|--help) usage; exit 0 ;;
    *) die "unknown option: $1 (try --help)" ;;
  esac
done

# The owner's escalation ladder (2026-10-21), applied only when neither roster was given, so -m or
# --or alone still means "these reviewers and nothing else". Models are chosen from a 13-model
# OpenRouter test: grok and muse found the real defects, the cheaper approvers found none.
case "$TIER" in 2|3|4) ;; *) die "--tier must be 2, 3 or 4" ;; esac
if [ ${#AGY_MODELS[@]} -eq 0 ] && [ ${#OR_MODELS[@]} -eq 0 ]; then
  ladder=(g-pro grok)
  [ "$TIER" -ge 3 ] && ladder+=(muse)
  [ "$TIER" -ge 4 ] && ladder+=(astra)
  for alias in "${ladder[@]}"; do
    OR_MODELS+=("$("$BIN/model-id" --openrouter "$alias")")
  done
fi
case "$QUESTION" in
  @*) QUESTION="$(cat "${QUESTION#@}")" ;;
esac

[ ${#AGY_MODELS[@]} -eq 0 ] || command -v agy >/dev/null 2>&1 || die "agy is not on PATH"
[ -r "$SCHEMA" ] || die "missing schema: $SCHEMA"
[ -r "$NORM_SCHEMA" ] || die "missing transcription schema: $NORM_SCHEMA"
[ -r "$MERGE" ] || die "missing merger: $MERGE"

# ---------------------------------------------------------------- material ---

if [ "$TARGET" != "-" ]; then
  if [ -z "$REPO" ]; then
    REPO="$(git rev-parse --show-toplevel 2>/dev/null || true)"
  fi
  [ -n "$REPO" ] || die "not inside a git repository; pass -C DIR or use -t -"
fi

# mktemp rather than a name built from $$: on a host where TMPDIR is unset the
# run directory lands in a world-writable /tmp, where a predictable name lets
# anyone pre-create it full of symlinks and have the first `: >` truncate
# whatever they point at.
RUN="$(mktemp -d "${TMPDIR:-/tmp}/second-opinion.XXXXXXXX")"
if [ "$KEEP" = 0 ]; then
  # find rather than a glob: `*` skips dotfiles, so a reviewer dropping a .cache
  # in the neutral directory would defeat the rmdir and strand the whole tree.
  trap 'find "$RUN" -mindepth 1 -delete 2>/dev/null; rmdir "$RUN" 2>/dev/null || true' EXIT
fi

# Paths are collected NUL-delimited: git C-quotes any name holding a tab, a
# newline or a non-ASCII byte, and a quoted name fails every later -r test, so a
# line-based list drops exactly the files whose contents are hardest to guess at.
TOUCHED="$RUN/touched"
: > "$TOUCHED"

material=""
case "$TARGET" in
  -)
    material="$(cat)"
    ;;
  working)
    material="$(git -C "$REPO" diff HEAD)"
    git -C "$REPO" diff HEAD -z --name-only > "$TOUCHED"
    ;;
  staged)
    material="$(git -C "$REPO" diff --cached)"
    git -C "$REPO" diff --cached -z --name-only > "$TOUCHED"
    ;;
  branch|branch:*)
    base="${TARGET#branch}"; base="${base#:}"; base="${base:-main}"
    git -C "$REPO" rev-parse --verify "$base" >/dev/null 2>&1 || die "no such base ref: $base"
    material="$(git -C "$REPO" diff "$base...HEAD")"
    git -C "$REPO" diff "$base...HEAD" -z --name-only > "$TOUCHED"
    ;;
  commit:*)
    ref="${TARGET#commit:}"
    git -C "$REPO" rev-parse --verify "$ref" >/dev/null 2>&1 || die "no such ref: $ref"
    material="$(git -C "$REPO" show "$ref")"
    git -C "$REPO" show -z --name-only --format= "$ref" > "$TOUCHED"
    ;;
  files:*)
    # tr leaves the last element unterminated, and `read -d ''` needs the
    # delimiter to hand the value to the loop body at all.
    { printf '%s' "${TARGET#files:}" | tr ',' '\0'; printf '\0'; } > "$TOUCHED"
    while IFS= read -r -d '' f; do
      [ -n "$f" ] || continue
      path="$REPO/$f"
      [ -r "$path" ] || path="$f"
      [ -r "$path" ] || die "cannot read file: $f"
      material="$material
--- FILE $f ---
$(cat "$path")
"
    done < "$TOUCHED"
    ;;
  *) die "unknown target: $TARGET (try --help)" ;;
esac

[ -n "$(printf '%s' "$material" | tr -d '[:space:]')" ] || die "nothing to review for target '$TARGET'"

if [ "$FULL" = 1 ]; then
  while IFS= read -r -d '' f; do
    [ -n "$f" ] || continue
    [ -r "$REPO/$f" ] || continue
    material="$material

--- CURRENT FULL CONTENTS: $f ---
$(cat "$REPO/$f")"
  done < "$TOUCHED"
fi

size=$(printf '%s' "$material" | wc -c | tr -d ' ')
if [ "$size" -gt "$MAX_BYTES" ]; then
  die "material is ${size} bytes, over the ${MAX_BYTES} limit; narrow the target or drop --full"
fi

# --------------------------------------------------------- credential scan ---

if [ "$ALLOW_SECRETS" = 0 ]; then
  hits="$(printf '%s' "$material" | grep -nEi \
    -e '(api[_-]?key|secret|passwd|password|token|credential)[[:space:]]*[:=][[:space:]]*["'"'"'][^"'"'"']{8,}' \
    -e 'sk-[A-Za-z0-9_-]{20,}' \
    -e 'ghp_[A-Za-z0-9]{28,}' \
    -e 'AKIA[0-9A-Z]{16}' \
    -e 'xox[baprs]-[A-Za-z0-9-]{10,}' \
    -e 'BEGIN [A-Z ]*PRIVATE KEY' \
    | cut -d: -f1 | tr '\n' ' ' || true)"
  if [ -n "$hits" ]; then
    note "second-opinion: possible credentials on lines: $hits"
    note "second-opinion: refusing to send. Inspect those lines, then re-run with --allow-secrets if they are false positives."
    exit 2
  fi
fi

# ------------------------------------------------------------------ prompt ---

read -r -d '' INSTRUCTION <<'PROMPT' || true
You are an independent reviewer brought in for a second opinion on a change
another AI assistant produced. You are not the author and owe the author nothing.

Report only defects you can point at concretely, each with the location, what is
wrong, and the concrete failure it causes: inputs or state leading to wrong
behaviour. Severity is P0 for data loss, a security hole, or breakage on the
common path; P1 for wrong under a realistic input; P2 for maintainability, a
missing test, or a broken contract; P3 for a nit. Rank most severe first.

Mark a finding "confirmed" only when the material on hand proves it. Anything
resting on code you were not shown is "unverified", and you must say what
evidence would settle it. Do not invent findings to appear diligent: if the
change is correct, say so and return an empty findings list. No summary of what
the code does, no praise, no restating the request.

You have no file access, no shell and no tools, and the paths named below do not
exist where you are running. Everything you are given is in the material. Do not
try to read a file, list a directory or run a command: the attempt is denied and
costs you your entire answer. Reason from the material alone, and mark as
"unverified" whatever it does not settle.
PROMPT

if [ -n "$QUESTION" ]; then
  context="What the author wants checked:
$QUESTION"
else
  context="No focus was supplied; judge the change on its own terms."
fi

prompt="$INSTRUCTION

$context

--- BEGIN MATERIAL ---
$material
--- END MATERIAL ---"

# ----------------------------------------------------------------- reviews ---

[ -n "$OUT" ] || OUT="$RUN/report.json"

manifest="$RUN/manifest.json"
NEUTRAL="$RUN/cwd"
mkdir -p "$NEUTRAL"

# A stalled OpenRouter connection would otherwise hang `wait` for as long as the
# API cares to keep the socket open, holding the whole panel hostage.
case "$TIMEOUT" in
  *m) OPENROUTER_TIMEOUT=$(( ${TIMEOUT%m} * 60 )) ;;
  *s) OPENROUTER_TIMEOUT="${TIMEOUT%s}" ;;
  *[0-9]) OPENROUTER_TIMEOUT="$TIMEOUT" ;;
  *) OPENROUTER_TIMEOUT=300 ;;
esac
export OPENROUTER_TIMEOUT
: > "$RUN/entries"
: > "$RUN/files"

slug() { printf '%s' "$1" | tr '/:' '__'; }

note "second-opinion: ${size} bytes to ${#AGY_MODELS[@]} agy and ${#OR_MODELS[@]} OpenRouter reviewer(s)..."

# The index keeps the path unique when the same model is listed twice, which is
# a legitimate way to ask one model for two independent passes; without it both
# subshells would write the same file concurrently and corrupt each other.
idx=0

# Repeated models get a distinct label as well as a distinct file. The merger
# refuses to cluster two findings from one reviewer, so without this a second
# pass of the same model could never corroborate the first — and corroboration
# is the only thing a repeated pass is for.
label_for() {
  if grep -Fq "\"reviewer\":\"$1\"" "$RUN/entries" 2>/dev/null; then
    printf '%s#%s' "$1" "$2"
  else
    printf '%s' "$1"
  fi
}

for m in ${AGY_MODELS[@]+"${AGY_MODELS[@]}"}; do
  idx=$((idx + 1))
  f="$RUN/agy.$idx.$(slug "$m").json"
  label="$(label_for "$m" "$idx")"
  printf '{"reviewer":"%s","engine":"agy","file":"%s"}\n' "$label" "$f" >> "$RUN/entries"
  printf '%s\t%s\n' "$label" "$f" >> "$RUN/files"
  (
    # Run from an empty directory. agy is an agent, not a completion endpoint:
    # when the paths named in a diff resolve under its working directory it goes
    # to read them, and in headless mode that tool call is auto-denied and takes
    # the whole answer down with it. With nothing to reach for, it reviews.
    cd "$NEUTRAL" && printf '%s' "$prompt" | agy \
      --model "$m" \
      --output-format json \
      --json-schema "$SCHEMA" \
      --print-timeout "$TIMEOUT" \
      > "$f" 2> "$f.err" || true
  ) &
done

if [ ${#OR_MODELS[@]} -gt 0 ]; then
  [ -x "$OPENROUTER" ] || die "OpenRouter reviewers requested but $OPENROUTER is missing"
  schema_text="$(cat "$SCHEMA")"
  or_prompt="$prompt

Respond with a single JSON object and nothing else, matching this schema:
$schema_text"
  for m in "${OR_MODELS[@]}"; do
    idx=$((idx + 1))
    f="$RUN/or.$idx.$(slug "$m").json"
    label="$(label_for "$m" "$idx")"
    printf '{"reviewer":"%s","engine":"openrouter","file":"%s"}\n' "$label" "$f" >> "$RUN/entries"
    printf '%s\t%s\n' "$label" "$f" >> "$RUN/files"
    (
      printf '%s' "$or_prompt" | "$OPENROUTER" -m "$m" --think high -n 16000 > "$f" 2> "$f.err" || true
    ) &
  done
fi

wait

# Transcribe any reviewer that answered in prose. This judges nothing: the
# normalizer is told to carry findings across verbatim, so a reviewer's opinion
# survives its refusal to fill in a schema.
NORMALIZE="$BIN/second-opinion-normalize.py"
while IFS=$'\t' read -r reviewer f; do
  [ -n "$f" ] || continue
  case "$f" in "$RUN/or."*) engine="openrouter" ;; *) engine="agy" ;; esac
  if prose="$(python3 "$NORMALIZE" check "$f" "$engine")"; then
    note "second-opinion: $reviewer answered in prose, transcribing with $NORMALIZER"
    printf 'Transcribe the code review below into the required schema. Carry every
finding across exactly as written: do not add findings, do not drop findings, do
not re-judge severity or confidence. Where the review omits a field, infer the
most conservative value it supports. The overall verdict is "approve" only if
the review reports no P0 and no P1.

First decide whether the text is a review at all. If it is a refusal, an
apology, an error, a request for more material, a plan for a review not yet
done, or anything else that does not actually report on code, set is_review to
false, say in "reason" what it is instead, and leave findings empty. Never
transcribe a non-review into an approval.

--- REVIEW TEXT ---
%s' "$prose" | (cd "$NEUTRAL" && agy \
      --model "$NORMALIZER" \
      --output-format json \
      --json-schema "$NORM_SCHEMA" \
      --print-timeout "$TIMEOUT") \
      > "$f.norm" 2> "$f.norm.err" || true
    # normalize.py stamps the file itself when it rejects a transcription, but it
    # cannot do so if it never runs or dies on a signal. Stamping again here costs
    # nothing and closes the one gap that would leave mineable prose on disk.
    if ! python3 "$NORMALIZE" apply "$f" "$engine" "$f.norm"; then
      note "second-opinion: transcription failed for $reviewer; its findings are lost"
      python3 -c 'import json,sys; print(json.dumps({"status": "ERROR",
        "error": "transcription failed for %s" % sys.argv[1]}))' "$reviewer" > "$f"
    fi
  fi
done < "$RUN/files"

python3 -c 'import json,sys
print(json.dumps([json.loads(l) for l in open(sys.argv[1]) if l.strip()]))' "$RUN/entries" > "$manifest"

merge_rc=0
python3 "$MERGE" "$manifest" "$OUT" || merge_rc=$?

for e in "$RUN"/*.err; do
  [ -s "$e" ] || continue
  note ""
  note "stderr from $(basename "$e" .err):"
  sed 's/^/    /' "$e" >&2
done

if [ "$KEEP" = 1 ]; then
  note ""
  note "raw reviewer output kept in $RUN"
fi
exit "$merge_rc"
