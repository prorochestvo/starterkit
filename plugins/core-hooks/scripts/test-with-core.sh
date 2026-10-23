#!/usr/bin/env bash
# Tests for with-core.sh: dedupe against settings.json, the core lookup through the plugin
# registry, neither present, and a missing hook file.
#
# Usage: plugins/core-hooks/scripts/test-with-core.sh
# Runs in a temporary directory with its own CLAUDE_CONFIG_DIR and CLAUDE_PLUGIN_ROOT; it
# reads nothing from the real configuration. Exit status 0 when every case passes.
set -euo pipefail

here="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
launcher="$here/with-core.sh"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

failures=0
pass() { echo "ok   $1"; }
fail() { echo "FAIL $1: $2"; failures=$((failures + 1)); }

hook=fake-hook.sh
plugin="$tmp/plugin"
core="$tmp/core-install"
mkdir -p "$plugin/hooks" "$core/bin"

# The hook records that it ran, what it read on stdin and which model-id it resolves,
# then exits 3 so the test sees the hook's own status come back.
cat >"$plugin/hooks/$hook" <<EOF
#!/usr/bin/env bash
{ echo ran; cat; echo; command -v model-id || echo no-model-id; } >"$tmp/hook.out"
exit 3
EOF
chmod +x "$plugin/hooks/$hook"
printf '#!/bin/sh\necho stub\n' >"$core/bin/model-id"
chmod +x "$core/bin/model-id"

registry_json() {
  cat <<EOF
{"version": 2, "plugins": {"core@starterkit": [
  {"scope": "user", "installPath": "$core", "version": "test"}
]}}
EOF
}

settings_json() { # <command>
  cat <<EOF
{"hooks": {"PreToolUse": [{"matcher": "Bash", "hooks": [
  {"type": "command", "command": "$1"}
]}]}}
EOF
}

# run <case name> <hook name>: runs the launcher with a fresh config directory prepared by
# the caller in $tmp/config; sets status, out (stdout) and err (stderr).
run() {
  rm -f "$tmp/hook.out"
  set +e
  out="$(printf 'payload' | CLAUDE_CONFIG_DIR="$tmp/config" CLAUDE_PLUGIN_ROOT="$plugin" \
    CLAUDE_PROJECT_DIR="$tmp/project" "$launcher" "$2" 2>"$tmp/err")"
  status=$?
  set -e
  err="$(cat "$tmp/err")"
}

reset_config() {
  rm -rf "$tmp/config"
  mkdir -p "$tmp/config/plugins"
}

# 1. Dedupe: settings.json registers the same hook file, so the launcher stays silent even
#    though core is installed.
reset_config
registry_json >"$tmp/config/plugins/installed_plugins.json"
settings_json "\${CLAUDE_CONFIG_DIR}/hooks/$hook" >"$tmp/config/settings.json"
run dedupe "$hook"
if [ "$status" -eq 0 ] && [ -z "$out$err" ] && [ ! -e "$tmp/hook.out" ]; then
  pass "dedupe: a hook registered in settings.json is skipped silently"
else
  fail dedupe "status=$status out='$out' err='$err' ran=$([ -e "$tmp/hook.out" ] && echo yes || echo no)"
fi

# 1b. Dedupe matches the base name of a word, not a substring of the command.
reset_config
registry_json >"$tmp/config/plugins/installed_plugins.json"
settings_json "\${CLAUDE_CONFIG_DIR}/hooks/other-$hook" >"$tmp/config/settings.json"
run dedupe-substring "$hook"
if [ "$status" -eq 3 ] && [ -e "$tmp/hook.out" ]; then
  pass "dedupe: a different hook file with a similar name does not count"
else
  fail dedupe-substring "status=$status err='$err'"
fi

# 2. Registry: core is found through installed_plugins.json, its bin/ is on PATH, stdin
#    reaches the hook and the hook's exit status comes back.
reset_config
registry_json >"$tmp/config/plugins/installed_plugins.json"
run registry "$hook"
if [ "$status" -eq 3 ] && [ -z "$err" ] && [ -e "$tmp/hook.out" ] &&
  grep -qx payload "$tmp/hook.out" && grep -qx "$core/bin/model-id" "$tmp/hook.out"; then
  pass "registry: the hook runs with core's bin/ on PATH and its own status"
else
  fail registry "status=$status err='$err' hook.out='$(cat "$tmp/hook.out" 2>/dev/null)'"
fi

# 3. Neither: no settings entry and no core in the registry; one line, exit 0, no hook run.
reset_config
run neither "$hook"
lines="$(printf '%s' "$err" | grep -c . || true)"
if [ "$status" -eq 0 ] && [ -z "$out" ] && [ "$lines" -eq 1 ] && [ ! -e "$tmp/hook.out" ] &&
  printf '%s' "$err" | grep -q 'core@starterkit'; then
  pass "neither: one line naming core@starterkit, exit 0"
else
  fail neither "status=$status lines=$lines err='$err'"
fi

# 4. Missing hook file: exit 0 without output, whatever the registry holds.
reset_config
registry_json >"$tmp/config/plugins/installed_plugins.json"
run missing no-such-hook.sh
if [ "$status" -eq 0 ] && [ -z "$out$err" ]; then
  pass "missing hook file: exit 0 without output"
else
  fail missing "status=$status out='$out' err='$err'"
fi

if [ "$failures" -ne 0 ]; then
  echo "$failures failing"
  exit 1
fi
echo "all passed"
