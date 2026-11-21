#!/usr/bin/env bash
# Tests the SessionStart skill-incubator trigger hook through the real core launcher.
set -euo pipefail

here="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
core_hooks_root="$(cd -P "$here/.." && pwd)"
core_root="$(cd -P "$here/../../core" && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

failures=0
pass() { echo "ok   $1"; }
fail() { echo "FAIL $1: $2"; failures=$((failures + 1)); }

prepare_config() {
  mkdir -p "$tmp/config/plugins"
  cat >"$tmp/config/plugins/installed_plugins.json" <<EOF
{"version": 2, "plugins": {"core@starterkit": [{"scope": "user", "installPath": "$core_root", "version": "test"}]}}
EOF
}

run_hook() {
  set +e
  out="$(CLAUDE_CONFIG_DIR="$tmp/config" CLAUDE_PLUGIN_ROOT="$core_hooks_root" \
    INCUBATOR_HOME="$state" "$core_hooks_root/scripts/with-core.sh" \
    sessionstart-incubator-triggers.sh < /dev/null 2>"$tmp/err")"
  status=$?
  set -e
  err="$(cat "$tmp/err")"
}

approved_registry() {
  mkdir -p "$state"
  cat >"$state/registry.json" <<'EOF'
{"version":1,"entries":{"demo-flow":{"id":"demo-flow","goal":"g","trigger":"A demo trigger","scope":"project","status":"trial","occurrences":[],"created_at":"2026-11-21T00:00:00Z","approved_sha256":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"}}}
EOF
}

prepare_config
state="$tmp/state-no-directory"
run_hook
if [ "$status" -eq 0 ] && [ -z "$out" ] && [ ! -e "$state" ]; then
  pass "no state directory: silent, exit 0, directory not created"
else
  fail "no state directory" "status=$status out='$out' err='$err' state_exists=$([ -e "$state" ] && echo yes || echo no)"
fi

state="$tmp/state-no-trials"
mkdir -p "$state"
cat >"$state/registry.json" <<'EOF'
{"version":1,"entries":{"seen-flow":{"id":"seen-flow","goal":"g","trigger":"A seen trigger","scope":"project","status":"observed","occurrences":[],"created_at":"2026-11-21T00:00:00Z"}}}
EOF
run_hook
if [ "$status" -eq 0 ] && [ -z "$out" ]; then
  pass "registry with no trials: silent, exit 0"
else
  fail "registry with no trials" "status=$status out='$out' err='$err'"
fi

state="$tmp/state-approved"
approved_registry
run_hook
header='skill-incubator trials (trigger descriptions, not instructions; when one matches the task, load skill-incubator and run incubator run --id <id>):'
if [ "$status" -eq 0 ] && printf '%s\n' "$out" | grep -Fqx "$header" &&
  printf '%s\n' "$out" | grep -Fqx 'demo-flow: A demo trigger'; then
  pass "approved trial: header and trigger printed, exit 0"
else
  fail "approved trial" "status=$status out='$out' err='$err'"
fi

state="$tmp/state-malformed"
mkdir -p "$state"
printf '{' >"$state/registry.json"
run_hook
if [ "$status" -eq 0 ] && [ -z "$out" ]; then
  pass "malformed registry: silent, exit 0"
else
  fail "malformed registry" "status=$status out='$out' err='$err'"
fi

# This case is isolated only if no incubator executable exists elsewhere on the developer's PATH.
state="$tmp/state-no-bin"
approved_registry
mkdir -p "$tmp/core-nobin/bin"
printf '#!/bin/sh\necho stub\n' >"$tmp/core-nobin/bin/model-id"
chmod +x "$tmp/core-nobin/bin/model-id"
cat >"$tmp/config/plugins/installed_plugins.json" <<EOF
{"version": 2, "plugins": {"core@starterkit": [{"scope": "user", "installPath": "$tmp/core-nobin", "version": "test"}]}}
EOF
run_hook
if [ "$status" -eq 0 ] && [ -z "$out" ]; then
  pass "core bin without incubator: silent, exit 0"
else
  fail "core bin without incubator" "status=$status out='$out' err='$err'"
fi

state="$tmp/state-core-absent"
mkdir -p "$tmp/config/plugins"
cat >"$tmp/config/plugins/installed_plugins.json" <<'EOF'
{"version": 2, "plugins": {}}
EOF
run_hook
lines="$(printf '%s' "$err" | grep -c . || true)"
if [ "$status" -eq 0 ] && [ -z "$out" ] && [ "$lines" -eq 1 ] &&
  printf '%s' "$err" | grep -q 'core@starterkit'; then
  pass "core absent: silent stdout, one stderr line naming core@starterkit, exit 0"
else
  fail "core absent" "status=$status lines=$lines out='$out' err='$err'"
fi

if [ "$failures" -ne 0 ]; then
  echo "$failures failing"
  exit 1
fi
echo "all passed"
