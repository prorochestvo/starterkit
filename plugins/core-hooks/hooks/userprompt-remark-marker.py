#!/usr/bin/env python3
"""UserPromptSubmit: make a ~wtf / ~ok prompt load skill-tuner instead of hoping it matches.

Fails open: any error prints nothing and exits 0, so a broken hook never blocks a prompt.
"""
import json
import re
import sys

MARKER = re.compile(r"^\s*~(wtf|wft|ok)(?![a-z])(\[[^\]]*\])?", re.IGNORECASE)


def main() -> None:
    try:
        prompt = json.load(sys.stdin).get("prompt") or ""
    except (ValueError, AttributeError):
        return
    m = MARKER.match(prompt)
    if not m:
        return
    kind = "~ok" if m.group(1).lower() == "ok" else "~WTF"
    context = (
        f"This prompt carries the owner's {kind} remark marker. After handling the request "
        "itself, invoke the `skill-tuner` skill with the Skill tool and run its full "
        "procedure: triage, edit, commit, log, chat report. Do not edit any skill without "
        "loading skill-tuner first."
    )
    print(json.dumps({"hookSpecificOutput": {
        "hookEventName": "UserPromptSubmit", "additionalContext": context}}))


if __name__ == "__main__":
    try:
        main()
    except Exception:  # noqa: BLE001 — fail open
        pass
