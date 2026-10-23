#!/usr/bin/env python3
"""Print the live Codex rate limits, the way `agy -p /usage` does for Gemini.

Asks `codex app-server` over stdio JSON-RPC (account/rateLimits/read). That is a
live request: the session rollouts under ~/.codex/sessions only hold the value
from the last non-ephemeral Codex turn, which can be days old.
"""
import datetime, json, subprocess, sys, time

proc = subprocess.Popen(["codex", "app-server"], stdin=subprocess.PIPE,
                        stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, text=True)


def send(message):
    proc.stdin.write(json.dumps(message) + "\n")
    proc.stdin.flush()


send({"jsonrpc": "2.0", "id": 1, "method": "initialize",
      "params": {"clientInfo": {"name": "codex-limits", "version": "1"}}})
send({"jsonrpc": "2.0", "method": "initialized", "params": {}})
send({"jsonrpc": "2.0", "id": 2, "method": "account/rateLimits/read"})

result, deadline = None, time.time() + 30
while time.time() < deadline:
    line = proc.stdout.readline()
    if not line:
        break
    message = json.loads(line)
    if message.get("id") == 2:
        result = message.get("result")
        if result is None:
            sys.exit("codex: %s" % message.get("error"))
        break
proc.kill()
if result is None:
    sys.exit("codex: no answer from app-server within 30s")

limits = result.get("rateLimits") or {}
names = {300: "5-hour", 10080: "weekly"}
print("plan: %s" % limits.get("planType"))
for key in ("primary", "secondary"):
    window = limits.get(key)
    if not window:
        continue
    resets = datetime.datetime.fromtimestamp(window["resetsAt"]).strftime("%Y-%m-%d %H:%M")
    label = names.get(window.get("windowDurationMins"), "%s min" % window.get("windowDurationMins"))
    print("%-7s used %3d%%   resets %s" % (label, window.get("usedPercent", 0), resets))
credits = (result.get("rateLimitResetCredits") or {}).get("availableCount")
if credits:
    print("free full resets available: %d" % credits)
if limits.get("rateLimitReachedType"):
    print("LIMIT REACHED: %s" % limits["rateLimitReachedType"])
