#!/usr/bin/env python3
"""PreToolUse (matcher: AskUserQuestion): advisory quorum before interrupting
the owner.

When the main session wants to ask the user a multiple-choice question, a
two-family panel - headless Claude and Codex sol - answers it first. OpenRouter
counts only as a stand-in for a panel member that did not answer, and Codex only
when the votes are still short; see the ADVISORS block for why.
Every question in the batch resolved unanimously: the call is blocked (exit 2)
and the agreed options are fed back so the session proceeds without
interrupting the owner. Any disagreement, any ESCALATE, or a question shape the
advisors cannot answer: the whole batch passes through (fail open - this hook
must never eat a question it could not confidently answer).

Batches are the normal case, not the exception: the global instructions require
questions to be asked together rather than one per turn. An earlier version
accepted only a single-question call and silently returned on the rest, which
measured 12 of 18 calls dropped before an advisor was ever asked.

Consensus is taken among the voices that count, minimum two. A slow or
unauthenticated panel member is replaced by the stand-in instead of disabling
the quorum - relevant because a Codex model can be at capacity.
"""
import concurrent.futures, json, os, re, shutil, subprocess, sys, time

# Hooks inherit a non-interactive PATH, which on Linux omits ~/.local/bin; the helpers
# (model-id, openrouter-cli) and claude/agy/codex live in one of these on both hosts.
EXTRA_PATH = ["/opt/homebrew/bin", "/usr/local/bin", os.path.join(os.path.expanduser("~"), ".local", "bin")]


def model_id(alias):
    """Exact id for a model alias (terra, g-pro) from model-id on PATH; "" when it does not resolve."""
    try:
        return subprocess.run(["model-id", alias], capture_output=True, text=True, timeout=5,
                              env=dict(os.environ, PATH=":".join(EXTRA_PATH + [os.environ.get("PATH", "")]))
                              ).stdout.strip()
    except (OSError, subprocess.SubprocessError):
        return ""


CODEX_MODEL = os.environ.get("QUORUM_CODEX_MODEL") or model_id("terra")
CLAUDE_MODEL = os.environ.get("QUORUM_CLAUDE_MODEL", "fable")
SOL_MODEL = os.environ.get("QUORUM_SOL_MODEL") or model_id("sol")
# The hook's timeout in settings.json differs per host (150s is the smallest in
# use). The panel and the stand-in run in one parallel round; Codex may then run
# a second, and both must fit inside the smallest budget.
ADVISOR_TIMEOUT = 90
FALLBACK_TIMEOUT = 50
MIN_ANSWERS = 2

# OpenRouter is a stand-in, never a standing voter: its own skill rates a cheap
# model's opinion as noise on a judgement call, and as a standing voter its
# agreement with Claude alone was enough to keep a question from the owner.
OPENROUTER = "openrouter-cli"
OPENROUTER_TIER = os.environ.get("QUORUM_OPENROUTER_TIER", "luna")

# Without a log, "the quorum does not seem to work" cannot be confirmed or
# refuted - which is exactly how the single-question bug survived unnoticed.
# Runtime state: ${CLAUDE_CONFIG_DIR:-$HOME/.claude}/runtime-state/question-quorum/
LOG_DIR = os.path.join(os.environ.get("CLAUDE_CONFIG_DIR") or os.path.expanduser("~/.claude"), "runtime-state",
                       "question-quorum")
LOG_PATH = os.path.join(LOG_DIR, "quorum.log")
LOG_MAX = 512_000

PROMPT = """You are one of three independent advisors resolving a multiple-choice \
question raised during a coding session. The goal: the owner is interrupted only \
when advisors disagree or the question is genuinely theirs to answer.

Rules:
- If the decision requires the owner's personal preference, private knowledge, \
scope call, or business context - rather than technical judgment - reply on the \
first line: ESCALATE: <one-line why>.
- Otherwise pick the single best option on technical merit. First line: \
CHOICE: <the option label ONLY, verbatim - no description, nothing after it>. \
Second line: REASON: <one sentence>.
- Output nothing else.

"""


def log(msg):
    try:
        os.makedirs(LOG_DIR, mode=0o700, exist_ok=True)
        if os.path.exists(LOG_PATH) and os.path.getsize(LOG_PATH) > LOG_MAX:
            os.replace(LOG_PATH, LOG_PATH + ".1")
        with open(LOG_PATH, "a", encoding="utf-8") as fh:
            fh.write(f"{time.strftime('%Y-%m-%dT%H:%M:%S')} {msg}\n")
    except OSError:
        pass  # logging must never be the reason a question is eaten


def _augmented_path():
    """PATH with the places claude/agy/codex live on both a Mac and a Linux host.

    Hooks inherit a non-interactive PATH, which on Linux omits ~/.local/bin -
    that omission is why `command -v agy` reported the binary missing.
    """
    return ":".join(EXTRA_PATH + [os.environ.get("PATH", "")])


def env_with_guards():
    env = dict(os.environ,
               QUESTION_QUORUM_ACTIVE="1",
               COMMIT_MSG_REVIEW_ACTIVE="1",
               PRECOMPACT_SYNTH_ACTIVE="1",
               PATH=_augmented_path())
    return env


def _run(argv, timeout=ADVISOR_TIMEOUT):
    try:
        r = subprocess.run(argv, capture_output=True, text=True,
                           timeout=timeout, env=env_with_guards())
    except (subprocess.TimeoutExpired, FileNotFoundError, OSError):
        return None
    return r.stdout.strip() if r.returncode == 0 else None


def ask_codex(block):
    # codex prints a chatty transcript; the answer is at the tail
    return _run(["codex", "exec", "--ephemeral", "--skip-git-repo-check",
                 "-s", "read-only", "-m", CODEX_MODEL, PROMPT + block],
                timeout=FALLBACK_TIMEOUT)


def ask_claude(block):
    return _run(["claude", "-p", "--model", CLAUDE_MODEL, PROMPT + block])


def ask_sol(block):
    return _run(["codex", "exec", "--ephemeral", "--skip-git-repo-check",
                 "-s", "read-only", "-m", SOL_MODEL, "-c", 'model_reasoning_effort="low"',
                 PROMPT + block])


def ask_openrouter(block):
    if not shutil.which(OPENROUTER, path=_augmented_path()):
        return None
    return _run([OPENROUTER, "-t", OPENROUTER_TIER, "-s", PROMPT, block],
                timeout=ADVISOR_TIMEOUT)


# The standing panel is two model families of real judgement: the Claude
# subscription and Codex sol (Gemini Pro until agy withdrew it on 2026-10-19).
# From 2026-09-20 to 2026-10-04 the second seat was
# OpenRouter's cheapest GPT, because the paid quotas were burning - but the burn
# was the commit-message hook calling Gemini on every commit, which now runs on a
# cheap pinned model, while this hook sees a question or two a day.
# A split goes straight to the owner. Every counted voice must agree, so a third
# vote can never turn a split into consensus, and paying for one was waste. The
# stand-in and Codex exist only to fill a seat that went unanswered.
ADVISORS = {"claude": ask_claude, "sol": ask_sol}
STAND_IN = {"openrouter": ask_openrouter}
ESCALATION = {"codex": ask_codex}
VOICES = list(ADVISORS) + list(STAND_IN) + list(ESCALATION)


def parse(reply):
    """Return ('choice', label) | ('escalate', why) | None."""
    if not reply:
        return None
    m = re.search(r"^CHOICE:\s*(.+)$", reply, re.MULTILINE)
    if m:
        return ("choice", m.group(1).strip().strip("`\"'"))
    m = re.search(r"^ESCALATE:\s*(.+)$", reply, re.MULTILINE)
    if m:
        return ("escalate", m.group(1).strip())
    return None


# The asking session marks its own pick "(Recommended)", as the tool asks it to.
# Shown to the advisors, that label anchors them on the asker's answer and the
# quorum becomes a rubber stamp, so they see the bare label and the verdict is
# mapped back onto the original.
RECOMMENDED = re.compile(r"\s*\(recommended\)\s*$", re.IGNORECASE)


def bare(label):
    return RECOMMENDED.sub("", label or "")


def render(q):
    block = ["Question: " + (q.get("question") or ""), "", "Options:"]
    for o in q.get("options") or []:
        block.append(f"- {bare(o.get('label'))}: {o.get('description', '')}")
    return "\n".join(block)


def resolve(choice, options):
    """Map an advisor's CHOICE string onto exactly one original option label."""
    ch = bare(choice).lower().strip()
    hits = [o.get("label", "") for o in options
            if ch == bare(o.get("label")).lower()
            or ch.startswith(bare(o.get("label")).lower() + ":")
            or ch.startswith(bare(o.get("label")).lower() + " ")]
    return hits[0] if len(hits) == 1 else None


def answerable(q):
    """A shape the advisors can be asked about at all."""
    return not q.get("multiSelect") and len(q.get("options") or []) >= 2


def main():
    if os.environ.get("QUESTION_QUORUM_ACTIVE") == "1":
        return  # never recurse
    try:
        payload = json.load(sys.stdin)
    except Exception:
        return
    questions = ((payload.get("tool_input") or {}).get("questions")) or []
    if not questions:
        return
    unanswerable = [q for q in questions if not answerable(q)]
    if unanswerable:
        log(f"pass: {len(unanswerable)}/{len(questions)} question(s) are "
            f"multi-select or single-option; owner decides the batch")
        return

    # One parallel round over every (question, voice) pair, the stand-in included:
    # asking it later would cost a second round the hook budget cannot afford,
    # and a cheap call that is never counted costs next to nothing.
    first = {**ADVISORS, **STAND_IN}
    jobs = [(i, who) for i in range(len(questions)) for who in first]
    verdicts = {}

    def ask_round(pairs, table):
        with concurrent.futures.ThreadPoolExecutor(max_workers=len(pairs)) as pool:
            futs = {pool.submit(table[who], render(questions[i])): (i, who)
                    for i, who in pairs}
            for fut in concurrent.futures.as_completed(futs):
                i, who = futs[fut]
                try:
                    verdicts[(i, who)] = parse(fut.result())
                except Exception:
                    verdicts[(i, who)] = None

    ask_round(jobs, first)

    def counted(i):
        """The voices that count for question i: the panel, then the stand-in
        and Codex only to fill seats the panel left empty."""
        pool = {w: v for w in ADVISORS if (v := verdicts.get((i, w)))}
        for w in list(STAND_IN) + list(ESCALATION):
            if len(pool) >= MIN_ANSWERS:
                break
            if (v := verdicts.get((i, w))):
                pool[w] = v
        return pool

    short = [i for i in range(len(questions)) if len(counted(i)) < MIN_ANSWERS]
    if short:
        log(f"panel short on {len(short)} question(s); asking codex")
        ask_round([(i, who) for i in short for who in ESCALATION], ESCALATION)

    agreed = []
    for i, q in enumerate(questions):
        options = q.get("options") or []
        answered = counted(i)
        heard = {w: verdicts.get((i, w)) for w in VOICES if verdicts.get((i, w))}
        detail = " | ".join(f"{w}:{v[0]}={v[1][:40]}" for w, v in heard.items()) or "none answered"
        if len(answered) < MIN_ANSWERS:
            log(f"pass: q{i} only {len(answered)} voice(s) counted - {detail}")
            return
        if any(v[0] == "escalate" for v in answered.values()):
            log(f"pass: q{i} escalated - {detail}")
            return
        labels = {resolve(v[1], options) for v in answered.values()}
        if len(labels) != 1 or None in labels:
            log(f"pass: q{i} advisors split - {detail}")
            return
        agreed.append((q.get("question") or f"question {i + 1}", labels.pop(),
                       sorted(answered)))

    lines = ["Advisory quorum resolved this question - do NOT ask the user.",
             f"claude ({CLAUDE_MODEL}) and sol ({SOL_MODEL}) vote; openrouter "
             f"({OPENROUTER_TIER}) stands in for one that does not answer, codex "
             f"({CODEX_MODEL}) only if still short. Every counted voice agreed."]
    for question, label, who in agreed:
        lines.append(f"- {question}\n  -> {label}   (agreed by: {', '.join(who)})")
    lines.append("Proceed with those options now and note in your work that the "
                 "choice came from the advisor quorum.")
    log(f"blocked: {len(agreed)} question(s) resolved - "
        + "; ".join(f"{lbl}" for _, lbl, _ in agreed))
    print("\n".join(lines), file=sys.stderr)
    sys.exit(2)


if __name__ == "__main__":
    try:
        main()
    except SystemExit:
        raise
    except Exception as exc:  # never eat a question on a crash
        log(f"pass: crashed - {exc}")
        print(f"question quorum failed open: {exc}", file=sys.stderr)
    sys.exit(0)
