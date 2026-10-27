#!/usr/bin/env bash
# Plugin versions are YYYY.NNN: NNN counts the releases of one plugin within a year and
# restarts at 001 when the year changes. A pull request that changes plugins/<p>/ must carry
# the next number after the base branch for <p>.
#
#   plugin-version.sh stamp <base-ref>   set the next version on every changed plugin
#   plugin-version.sh check <base-ref>   exit 1 while a changed plugin lacks its next version
#
# Run from the repository root with <base-ref> fetched (e.g. origin/main). YEAR overrides the
# current UTC year (tests).
set -euo pipefail

mode="${1:-}"
base="${2:-}"
case "$mode" in stamp|check) ;; *) echo "usage: $0 stamp|check <base-ref>" >&2; exit 2 ;; esac
[ -n "$base" ] || { echo "usage: $0 stamp|check <base-ref>" >&2; exit 2; }

year="${YEAR:-$(date -u +%Y)}"

changed_plugins() {
  git diff --name-only "$base"...HEAD -- plugins/ | cut -d/ -f2 | sort -u
}

next_version() { # <plugin> -> the version after the base branch's one
  local current n
  current="$(git show "$base:plugins/$1/.claude-plugin/plugin.json" 2>/dev/null \
    | jq -r '.version // empty' 2>/dev/null || true)"
  if [[ "$current" =~ ^${year}\.([0-9]{3})$ ]]; then
    n=$((10#${BASH_REMATCH[1]} + 1))
  else
    n=1
  fi
  printf '%s.%03d\n' "$year" "$n"
}

status=0
for p in $(changed_plugins); do
  manifest="plugins/$p/.claude-plugin/plugin.json"
  [ -f "$manifest" ] || continue # plugin removed by this change
  want="$(next_version "$p")"
  have="$(jq -r '.version // empty' "$manifest")"
  if [ "$have" = "$want" ]; then
    echo "$p: $have"
    continue
  fi
  if [ "$mode" = check ]; then
    echo "$p: version is '${have:-none}', expected $want" >&2
    status=1
    continue
  fi
  tmp="$(mktemp)"
  jq --arg v "$want" '.version = $v' "$manifest" >"$tmp"
  mv "$tmp" "$manifest"
  echo "$p: ${have:-none} -> $want"
done
exit "$status"
