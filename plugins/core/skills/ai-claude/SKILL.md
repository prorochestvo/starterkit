---
name: ai-claude
description: Invoke a fresh headless Claude (`claude -p`) for utility LLM calls and fresh-context checks - distill a transcript or log, review a text against rules, look at a question without this session's assumptions. Use when the user says "спроси свежего клода", "прогони через haiku", or when a script/hook needs an embedded Claude call. Not a second opinion - same model family; Codex/Gemini run only when the owner asks for them (ai-codex, ai-gemini).
---

# Headless Claude calls

`claude -p` runs one prompt non-interactively and prints the response. Same
model family as this session: a utility call, not a second opinion. It burns
the Claude subscription quota, unlike `codex` and `agy`.

## Canonical invocation

```bash
printf '%s' "CONTEXT" | claude -p --model opus 'QUESTION' 2>/dev/null
```

- stdin works: piped input is appended to the prompt. Bulky context goes
  there, the instruction as the argument.
- Model aliases: `opus` (default - judgment tasks), `sonnet`, `haiku`
  (latency-critical mechanical checks only), `fable`.
- Prompt-only calls make no tool calls, so PreToolUse hooks stay quiet; the
  child still loads `~/.claude/settings.json`.

## Writing the prompt

- The child sees nothing of this session: include everything it needs.
- Ask for a concrete verdict or a fixed structure, not an essay.
- For an unbiased check, do not reveal your own conclusion.

## Calling from hooks and scripts

1. Recursion guards are mandatory: set a sentinel env var and check it at the
   hook's top, or a child that triggers the same hook loops forever. Set both
   existing sentinels, `COMMIT_MSG_REVIEW_ACTIVE` and
   `PRECOMPACT_SYNTH_ACTIVE`, plus your own for a new hook.
2. PATH: prepend `/opt/homebrew/bin:/usr/local/bin`; hook environments may
   lack Homebrew paths.
3. Fail open: wrap with a timeout; a non-zero exit, empty output, or garbled
   shape means "no answer". A quota lapse must never break the caller.
4. Validate the output shape (`APPROVE`/`REJECT`, a known heading) instead of
   trusting free text.

## When not to use this

- As a second opinion: no vendor diversity, and external reviewers run only
  when the owner asks (`ai-codex`, `ai-gemini`).
- For anything the session can do itself: zero session context, startup
  latency, quota.
