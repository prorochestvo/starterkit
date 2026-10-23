#!/usr/bin/env bash
# PreToolUse hook (matcher: Bash). Intercepts `git commit` commands, sends the
# commit message to a reviewer for a check against commit conventions.
#
# Only messages that land on an integration branch are reviewed: commits on
# main, stage, prod or dev (the squash that closes a feature branch) and
# `gh pr merge --squash`. Work-in-progress commits on any other branch are
# squashed away later, so they pass unreviewed and cost no model call.
#
# Three engines in order (see "Engine order" below); the next one runs only when
# the previous returned nothing usable, so a quota lapse, an outage, or a
# missing binary downgrades the review instead of skipping it.
# Exit 2 blocks the commit and feeds the reasons back to the agent so it rewrites
# the message; reviewer failures fail open so an API outage never bricks commits.
set -u

# Recursion guard: never re-enter if a review is active.
[ "${COMMIT_MSG_REVIEW_ACTIVE:-}" = "1" ] && exit 0

# Hooks inherit a non-interactive PATH; on Linux that omits ~/.local/bin.
export PATH="/opt/homebrew/bin:/usr/local/bin:$HOME/.local/bin:$PATH"

payload=$(cat)
cmd=$(printf '%s' "$payload" | jq -r '.tool_input.command // empty' 2>/dev/null) || exit 0
[ -n "$cmd" ] || exit 0
cwd=$(printf '%s' "$payload" | jq -r '.cwd // empty' 2>/dev/null)
[ -n "$cwd" ] || cwd=$PWD

# gh pr merge --squash: its subject and body become the commit on the base
# branch, so they get the full review. Without --subject GitHub would record
# the PR title unreviewed, so that form is refused.
read -r -d '' GH_MERGE <<'PY' || true
import os, re, shlex, sys
cmd = sys.stdin.read()
# A `"$(cat <<'EOF' ... EOF)"` body is literal text: inline it as one quoted word.
cmd = re.sub(r"\"\$\(cat\s*<<-?[ \t]*(['\"]?)(\w+)\1[ \t]*\n(.*?)\n[ \t]*\2[ \t]*\n\s*\)\"",
             lambda h: shlex.quote(h.group(3)), cmd, flags=re.S)
# Tokenise the whole command so a quoted multi-line --body stays one token;
# the merge's arguments end at the next shell separator.
lexer = shlex.shlex(cmd, posix=True, punctuation_chars=";&|()")
lexer.whitespace_split = True
try:
    tokens = list(lexer)
except ValueError:
    sys.exit(1)
start = next((k + 3 for k in range(len(tokens) - 2)
              if tokens[k:k + 3] == ["gh", "pr", "merge"]
              and (k == 0 or set(tokens[k - 1]) <= set(";&|()"))), None)
if start is None:
    sys.exit(1)
args = []
for t in tokens[start:]:
    if set(t) <= set(";&|()"):
        break
    args.append(t)
if "--squash" not in args and "-s" not in args:
    sys.exit(1)
subject = body = None
i = 0
while i < len(args):
    a = args[i]
    if a in ("--subject", "-t") and i + 1 < len(args):
        subject = args[i + 1]; i += 1
    elif a.startswith("--subject="):
        subject = a.split("=", 1)[1]
    elif a in ("--body", "-b") and i + 1 < len(args):
        body = args[i + 1]; i += 1
    elif a.startswith("--body="):
        body = a.split("=", 1)[1]
    elif a in ("--body-file", "-F") and i + 1 < len(args):
        path = args[i + 1]; i += 1
        body = open(path, encoding="utf-8").read() if os.path.isfile(path) else ""
    i += 1
if subject is None:
    print("NOSUBJECT")
    sys.exit(0)
if any("$(" in t or "`" in t for t in (subject, body or "")):
    print("UNRESOLVED")
    sys.exit(0)
out = subject.strip("\n")
if body and body.strip():
    out += "\n\n" + body.strip("\n")
sys.stdout.write(out)
PY
gh_msg=$(printf '%s' "$cmd" | python3 -c "$GH_MERGE" 2>/dev/null) || gh_msg=""
if [ "$gh_msg" = "NOSUBJECT" ]; then
  echo "gh pr merge --squash needs --subject (and --body): the squash message lands on the base branch and is reviewed here." >&2
  exit 2
fi
if [ "$gh_msg" = "UNRESOLVED" ]; then
  echo "gh pr merge --squash: write --subject and --body as literal text (or --body-file <file>); a command substitution cannot be reviewed before it runs." >&2
  exit 2
fi

# A real `git commit` invocation: at the start of the command or after a
# separator (incl. newline) - never the words "git commit" inside an
# argument (e.g. echo). Allows env-var prefixes (VAR=1 git ...) and any
# global options between `git` and `commit`; the trailing boundary
# (space, separator, or end) keeps `git commit-tree` out while accepting
# `git commit&&...`. False positives are safe: a command with no message
# that can be read off it exits below without a model call.
# Anchoring to line start only would miss `git add && git commit`.
sep=';&|('$'\n'
re_commit='(^|['"$sep"'])[[:space:]]*([A-Za-z_][A-Za-z0-9_]*=[^[:space:]]*[[:space:]]+)*git([[:space:]]+[^'"$sep"'[:space:]]+)*[[:space:]]+commit([[:space:]'"$sep"')]|$)'
if [ -z "$gh_msg" ]; then
  [[ "$cmd" =~ $re_commit ]] || exit 0

  # The repository the commit runs in: a `cd DIR` before the commit and a
  # `git -C DIR` move it away from the session cwd. A detached HEAD or an
  # unreadable branch is reviewed, as before this gate existed.
  read -r -d '' TARGET <<'PY' || true
import os, re, shlex, sys
cmd, d = sys.stdin.read(), sys.argv[1]
head = re.split(r"\bgit\b[^;&|\n]*\bcommit\b", cmd, maxsplit=1)[0]
# Variables assigned earlier in the same command (`W=/path; cd "$W"`) are expanded too, so a
# shell variable does not hide a feature branch and trigger a review it does not need.
assigned = {}
for a in re.finditer(r"(?:^|[;&|(\n])\s*(?:export\s+)?([A-Za-z_][A-Za-z0-9_]*)=([^\s;&|]+)", head):
    try:
        assigned[a.group(1)] = shlex.split(a.group(2))[0]
    except (ValueError, IndexError):
        pass
def resolve(base, raw):
    try:
        raw = shlex.split(raw)[0]
    except (ValueError, IndexError):
        return base
    raw = re.sub(r"\$\{?([A-Za-z_][A-Za-z0-9_]*)\}?", lambda v: assigned.get(v.group(1), v.group(0)), raw)
    return os.path.join(base, os.path.expandvars(os.path.expanduser(raw)))
for m in re.finditer(r"(?:^|[;&|(\n])\s*cd\s+(\S+)", head):
    d = resolve(d, m.group(1))
m = re.search(r"\bgit((?:\s+\S+)*?)\s+commit\b", cmd)
if m:
    c = re.search(r"-C\s+(\S+)", m.group(1))
    if c:
        d = resolve(d, c.group(1))
print(d)
PY
  repo=$(printf '%s' "$cmd" | python3 -c "$TARGET" "$cwd" 2>/dev/null) || repo=$cwd
  branch=$(git -C "$repo" symbolic-ref --short -q HEAD 2>/dev/null) || branch=""
  case "$branch" in
    ""|main|stage|prod|dev) ;;
    *) exit 0 ;;
  esac
fi

# No message-flag prefilter: the message is parsed out of the command below
# by a shell lexer, which handles tabs, line continuations and quoting that
# a regex prefilter kept missing.

# The format rules are measured here, not asked of a model. A free-tier model
# cannot count characters: it reported a 52-character header as 73 and 82, and
# the same message drew REJECT, APPROVE, REJECT on three runs. When the message
# can be read straight off the command, the header shape, its length, the "!"
# marker, the trailing period, the blank line and the 72-column wrap are
# decided here and only the judgement rules go to the model. When it cannot
# (no -m/-F message, command substitution, --cleanup, --trailer, an
# unreadable -F file), the hook exits 0 without a model call: the whole
# shell command is never sent to a reviewer.
read -r -d '' EXTRACT <<'PY' || true
import os, re, shlex, sys
cmd = sys.stdin.read()
if "$(" in cmd or "`" in cmd or "--cleanup" in cmd or "--trailer" in cmd:
    sys.exit(1)
heredoc = re.search(r"<<-?[ \t]*(['\"]?)(\w+)\1[^\n]*\n(.*?)\n[ \t]*\2[ \t]*(?:\n|$)", cmd, re.S)
if heredoc and re.search(r"(?:^|\s)(?:-F\s*-|--file(?:=|\s+)-)(?:\s|$)", cmd):
    sys.stdout.write(heredoc.group(3))
    sys.exit(0)
lexer = shlex.shlex(cmd, posix=True, punctuation_chars=";&|()")
lexer.whitespace_split = True
try:
    tokens = list(lexer)
except ValueError:
    sys.exit(1)
messages, in_commit, seen_git, i = [], False, False, 0
while i < len(tokens):
    tok = tokens[i]
    if set(tok) <= set(";&|()"):
        if in_commit:
            break
        seen_git = False
    elif tok == "git":
        seen_git = True
    elif seen_git and tok == "commit":
        in_commit = True
    elif in_commit:
        if tok in ("-m", "--message") and i + 1 < len(tokens):
            messages.append(tokens[i + 1]); i += 1
        elif tok.startswith("--message="):
            messages.append(tok.split("=", 1)[1])
        elif re.fullmatch(r"-[A-Za-z]+m", tok) and i + 1 < len(tokens):
            # combined short flags ending in m (`-am`): the next token is the message
            messages.append(tokens[i + 1]); i += 1
        elif tok.startswith("-m") and len(tok) > 2:
            messages.append(tok[2:])
        elif tok in ("-F", "--file") and i + 1 < len(tokens):
            path = tokens[i + 1]
            if path == "-" or not os.path.isfile(path):
                sys.exit(1)
            messages.append(open(path, encoding="utf-8").read().rstrip("\n")); i += 1
    i += 1
if not messages:
    sys.exit(1)
sys.stdout.write("\n\n".join(m.strip("\n") for m in messages))
PY

read -r -d '' FORMAT <<'PY' || true
import re, sys
msg = sys.stdin.read().rstrip("\n")
lines = msg.split("\n")
header, problems = lines[0], []
types = "feat|fix|refactor|docs|test|chore|revert"
if re.match(r"^[a-z]+(\([^)]*\))?!:", header):
    problems.append('header carries a "!" breaking-change marker; use a BREAKING CHANGE: footer')
elif not re.match(r"^(%s)(\([a-z0-9][a-z0-9._/-]*\))?: \S" % types, header):
    problems.append("header is not <type>(<scope>): <subject> with type one of %s and a lowercase scope" % types.replace("|", ", "))
if len(header) > 72:
    problems.append("header is %d characters; the limit is 72" % len(header))
if header.rstrip().endswith("."):
    problems.append("header ends with a period")
if len(lines) > 1 and lines[1].strip():
    problems.append("no blank line between the subject and the body")
for number, line in enumerate(lines[1:], 2):
    if len(line) > 72 and not re.search(r"https?://", line):
        problems.append("line %d is %d characters; wrap the body at 72" % (number, len(line)))
if re.search(r"(?im)^(co-authored-by:.*\b(claude|anthropic|gpt|openai|gemini|copilot)\b|claude-session:)", msg):
    problems.append("AI collaboration trailer")
print("\n".join("- " + p for p in problems))
PY

judgement_rules="1. Subject: imperative mood (\"add\", not \"added\"/\"adds\"); starts lowercase except proper nouns, brands, and acronyms; identifiers, file paths, and code tokens keep literal casing.
2. Body, if present: short, explaining what and why, not how. When the change took a default, a decision record belongs there: the choice, the alternative rejected, and what would reverse it. A violation is enumerating details the diff already shows (file lists, endpoint lists, env var wiring) or a body far longer than the change warrants (well over 150 words).
3. Task references (e.g., Jira tickets, GitHub issues like GM-111) are optional but must be placed at the very end of the message on a new line.
4. Mentions of AI collaboration (e.g., Claude-Session, Co-Authored-By AI) are strictly forbidden.
5. The message must be in English, professional, and free of profanity."
answer_format="Reply with exactly APPROVE or REJECT on the first line; if REJECT, list each violation on the following lines as a \"- R<n>: \" bullet, where <n> is the number of the rule above that the message breaks, then output a line that is exactly FIXED: followed by a corrected commit message (subject, plus body only if the original had one) that preserves the original intent and complies with every rule. Output nothing else."

if [ -n "$gh_msg" ]; then
  msg=$gh_msg
else
  msg=$(printf '%s' "$cmd" | python3 -c "$EXTRACT" 2>/dev/null) || msg=""
fi
if [ -n "$msg" ]; then
  format=$(printf '%s' "$msg" | python3 -c "$FORMAT" 2>/dev/null) || format=""
  if [ -n "$format" ]; then
    {
      echo "Commit message rejected by the format check (measured, not model-judged):"
      printf '%s\n' "$format"
    } >&2
    exit 2
  fi
  # A lowercase first letter settles the casing rule by measurement: luna
  # flagged "chore: snapshot consolidated skills" as uppercase on 1 of 3 runs.
  # An uppercase one stays with the model, which can tell a brand or acronym.
  rules="$judgement_rules"
  subject=$(printf '%s\n' "$msg" | head -n 1 | sed 's/^[^:]*: //')
  case "$subject" in
    [a-z]*) rules=$(printf '%s\n' "$judgement_rules" | sed 's/; starts lowercase except proper nouns, brands, and acronyms; identifiers, file paths, and code tokens keep literal casing\./. Casing is already verified; do not comment on it./') ;;
  esac
  prompt="You are reviewing a git commit message. Its format is already verified by code - the header shape and type, its length, the absence of a \"!\" marker and of a trailing period, the blank line after the subject, and the 72-column wrap. Do not judge or comment on any of those. Review only these rules:
$rules

Commit message:
$msg

Do not use any tools. Approve unless there is a clear violation. $answer_format"
else
  # The message cannot be read off the command: pass unreviewed, no model call.
  exit 0
fi

# Engine order: sol on the Codex plan, then opus on Claude Code. The first
# usable verdict wins; opus runs only when sol returned nothing usable (quota,
# capacity, outage, missing binary). No verdict from either fails open.
# History: qwen3.7-flash (2026-09-20 to 10-08) was consistent but wrong; luna
# contradicted itself under REJECT on about half of clean messages as the first
# reviewer (10-08 to 10-10) and again as the g-pro fallback (10-15/16), so it
# no longer reviews. g-pro left with agy on 2026-10-19 (gemini-3.1-pro was
# withdrawn); sol replaced it. Only integration commits reach this point, so
# the paid calls are few.
# Budget: 45 + 60 = 105s, under the 150s hook timeout in settings.json.
# Each engine can be repointed by env without editing this file. An alias that
# does not resolve leaves its engine empty, and an empty engine is skipped.
MODEL_ID="model-id"  # on PATH: the export above adds the directories that hold the link
SOL_MODEL="${COMMIT_MSG_REVIEW_SOL_MODEL:-$("$MODEL_ID" sol 2>/dev/null)}"
CLAUDE_MODEL="${COMMIT_MSG_REVIEW_CLAUDE_MODEL:-opus}"

# macOS ships no timeout(1); perl's alarm survives exec and is on both hosts.
bounded() { local secs=$1; shift; perl -e 'alarm shift; exec @ARGV' "$secs" "$@"; }

run_sol() {
  [ -n "$SOL_MODEL" ] && command -v codex >/dev/null 2>&1 || return 1
  local out; out=$(mktemp) || return 1
  # stdin with no prompt argument is the whole prompt; -o keeps only the answer.
  printf '%s' "$prompt" | COMMIT_MSG_REVIEW_ACTIVE=1 bounded 45 \
    codex exec --ephemeral --skip-git-repo-check --ignore-user-config -s read-only \
    -m "$SOL_MODEL" -c model_reasoning_effort="low" -o "$out" >/dev/null 2>&1
  cat "$out"; rm -f "$out"
}

# --setting-sources "" loads no user hooks, so the review cannot re-enter itself.
run_claude() {
  [ -n "$CLAUDE_MODEL" ] && command -v claude >/dev/null 2>&1 || return 1
  printf '%s' "$prompt" | COMMIT_MSG_REVIEW_ACTIVE=1 bounded 60 \
    claude -p --model "$CLAUDE_MODEL" --effort medium --setting-sources "" --tools "" 2>/dev/null
}

# What makes an engine "failed" is an unusable verdict, not a matched error
# string: CLI error wording changes between versions, an answer that is neither
# APPROVE nor REJECT does not. A genuine REJECT from any engine is final and
# never falls through.
#
# Models sometimes prepend blank lines or markdown emphasis; judge by the exact
# first word, cleaned - "REJECTED: service unavailable" is a reviewer error,
# not a rejection, and "cannot APPROVE" must not approve.
verdict=""
word=""
used=""
for engine in sol claude; do
  raw=$("run_$engine") || raw=""
  [ -n "$raw" ] || continue
  cleaned=$(printf '%s\n' "$raw" | awk '!/^[[:space:]]*```/' | awk 'p||NF{p=1; print}')
  first=$(printf '%s\n' "$cleaned" | tr -d '*`' | awk 'NF{print; exit}')
  candidate=$(printf '%s\n' "$first" | awk '{gsub(/[^A-Za-z]/, "", $1); print toupper($1)}')
  case "$candidate" in
    APPROVE|REJECT) verdict="$cleaned"; word="$candidate"; used="$engine"; break ;;
  esac
done

# No engine produced a verdict: fail open, an API outage must never brick commits.
[ -n "$word" ] || exit 0

case "$word" in
  APPROVE) exit 0 ;;
  REJECT)
    violations=$(printf '%s\n' "$verdict" | awk 'NR>1 && /^\**FIXED\**:?/{exit} NR>1{print}')
    fixed=$(printf '%s\n' "$verdict" | awk 'f{print} /^\**FIXED\**:?/{sub(/^\**FIXED\**:?\**[[:space:]]*/, ""); if ($0!="") print; f=1}')
    # Block only on a substantive rejection: at least one "- " bullet or a
    # non-blank correction. Bare REJECT, whitespace, or stray prose after a
    # REJECT-ish first line is a malformed reply, not a verdict: fail open.
    # A violation must name the rule it breaks; luna's false rejects named none.
    has_bullets=$(printf '%s\n' "$violations" | grep -cE '^[[:space:]]*- \**R[0-9]+' || true)
    [ "$has_bullets" -eq 0 ] && exit 0
    # A REJECT whose own reasoning ends in APPROVE talked itself out of the
    # rejection (luna, 2026-10-10: "... no other violations. APPROVE.").
    # APPROVE must open the line or follow a sentence end, so "cannot APPROVE"
    # and "DISAPPROVE" still reject; only the text before FIXED: counts.
    if printf '%s\n' "$violations" | awk 'NF{last=$0} END{exit !(last ~ /(^|[.!?][[:space:]]+)[*]*APPROVE[.!]?[*]*[[:space:]]*$/)}'; then
      exit 0
    fi
    # A "correction" identical to the message is a REJECT that found nothing:
    # luna has answered "No clear violations found" under a REJECT header.
    if [ -n "${msg:-}" ] && [ "$(printf '%s' "$fixed" | tr -d '[:space:]')" = "$(printf '%s' "$msg" | tr -d '[:space:]')" ]; then
      exit 0
    fi
    {
      case "$used" in
        sol) label="codex $SOL_MODEL" ;;
        *)   label="claude $CLAUDE_MODEL" ;;
      esac
      echo "Commit message rejected by AI review ($label). Violations:"
      printf '%s\n' "$violations"
      if [ -n "$fixed" ]; then
        echo ""
        echo "Reviewer-corrected message (same rules, intent preserved). Retry the"
        echo "commit with it verbatim, adjusting only if it misstates the change:"
        echo ""
        printf '%s\n' "$fixed"
      fi
    } >&2
    exit 2
    ;;
  *) exit 0 ;;
esac
