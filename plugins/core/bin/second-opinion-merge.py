#!/usr/bin/env python3
"""Merge independent reviewer verdicts into one ranked report.

Reads a manifest written by second-opinion.sh, pulls each reviewer's structured
findings out of whatever envelope its engine produced, clusters findings that
land on the same place in the same file, and ranks the result. Agreement between
reviewers is the signal worth surfacing: a defect two unrelated models flag
independently is far likelier to be real than either one alone.

Usage: second-opinion-merge.py MANIFEST.json OUT.json
"""

import json
import re
import sys
import textwrap

SEVERITY_ORDER = {"P0": 0, "P1": 1, "P2": 2, "P3": 3}
LINE_WINDOW = 8  # how far apart two reports of one defect may land

# Word overlap below which two findings stay separate defects. Set deliberately
# high: a false merge hides a real defect inside another one's "also" line, while
# a missed merge only costs a duplicate entry in the report. Lower it toward 0.25
# if genuinely paired findings keep landing in the single-reviewer section.
SIMILARITY_FLOOR = 0.32
WRAP = 96

STOPWORDS = set("""the and are its this that with for from not can will would should when
then than into out over under between within without which where what because but only
also more most other some such very already still just they them their there here have has
had been being does did doing use used using call called calls line code file function
method value values case cases return returns result results error errors issue issues
problem problems change changes new old same different possible potential may might could
""".split())


def die(msg):
    sys.stderr.write("second-opinion-merge: %s\n" % msg)
    raise SystemExit(1)


def extract(entry):
    """Return (verdict, summary, findings, error) for one reviewer."""
    try:
        with open(entry["file"]) as fh:
            raw = fh.read().strip()
    except IOError as exc:
        return None, None, [], "no output (%s)" % exc

    if not raw:
        return None, None, [], "empty output"

    payload = None
    if entry.get("engine") == "agy":
        try:
            envelope = json.loads(raw)
        except ValueError:
            return None, None, [], "unparseable envelope: %s" % raw[:200]
        if envelope.get("status") not in (None, "SUCCESS"):
            return None, None, [], envelope.get("error") or ("engine status %s" % envelope.get("status"))
        payload = envelope.get("structured_output")
        entry["duration"] = envelope.get("duration_seconds")
        # `or {}` rather than a default: an explicit "usage": null returns None
        # from .get, and the chained lookup would take the whole report down.
        entry["usage"] = (envelope.get("usage") or {}).get("total_tokens")
        if payload is None:
            # No fallback. An agy answer without structured output is prose, and
            # prose is the transcriber's job; by the time the report is built,
            # transcription has either replaced this file or stamped it failed.
            return None, None, [], "answered in prose and transcription did not produce a review"
    else:
        payload = coerce_json(raw)
        if isinstance(payload, dict) and payload.get("status") == "ERROR":
            return None, None, [], payload.get("error") or "engine failure"

    # A reviewer whose output could not be parsed must never be reported as a
    # reviewer that found nothing: silence and approval are opposite answers.
    if not isinstance(payload, dict):
        return None, None, [], "output was prose, not structured findings"
    if not isinstance(payload.get("findings"), list):
        return None, None, [], "output had no findings list"

    entry["normalized"] = bool(payload.get("_normalized"))
    return payload.get("verdict"), payload.get("summary"), payload["findings"], None


def coerce_json(text):
    """Parse an answer that is entirely JSON, optionally inside a fence.

    Deliberately no scan for JSON embedded in prose. Mining an object out of
    surrounding text cannot tell a report from an example the reviewer quoted
    while refusing, and picking wrong turns a refusal into a clean review. Prose
    belongs to the transcriber, which reads it in context and is allowed to say
    it was not a review at all.
    """
    if not text:
        return None
    text = text.strip()
    if text.startswith("```"):
        text = text.split("```")[1]
        if text.startswith("json"):
            text = text[4:]
        text = text.strip()
    try:
        return json.loads(text)
    except ValueError:
        return None


def describe(f):
    """Distinctive words of a finding, for judging whether two describe one defect."""
    text = ((f.get("title") or "") + " " + (f.get("failure") or "")).lower()
    words = re.findall(r"[a-z_][a-z0-9_]{2,}", text)
    return set(w for w in words if w not in STOPWORDS)


def overlap(a, b):
    """Overlap coefficient: forgiving when one reviewer is far wordier than the other."""
    ta, tb = describe(a), describe(b)
    if not ta or not tb:
        return 0.0
    return len(ta & tb) / float(min(len(ta), len(tb)))


def cluster(findings):
    """Group findings that describe one defect.

    Proximity alone over-merges: a dense function draws several unrelated
    findings within a few lines of each other. A group therefore needs the same
    file, nearby lines, and wording that actually overlaps — and holds at most
    one finding per reviewer, since a reviewer listing two findings is reporting
    two defects, not one twice.
    """
    groups = []
    for f in findings:
        path = (f.get("file") or "?").strip().lstrip("./")
        try:
            line = int(f.get("line") or 0)
        except (TypeError, ValueError):
            line = 0

        best, best_score = None, 0.0
        for g in groups:
            if g["file"] != path:
                continue
            if any(i["_reviewer"] == f["_reviewer"] for i in g["items"]):
                continue
            near = line == 0 or g["line"] == 0 or abs(g["line"] - line) <= LINE_WINDOW
            if not near:
                continue
            score = max(overlap(f, i) for i in g["items"])
            if score >= SIMILARITY_FLOOR and score > best_score:
                best, best_score = g, score

        if best is not None:
            best["items"].append(f)
            if best["line"] == 0:
                best["line"] = line
        else:
            groups.append({"file": path, "line": line, "items": [f]})
    return groups


def sev(value):
    """Severity rank, case-tolerant: a reviewer answering "p0" must not file as a nit."""
    return SEVERITY_ORDER.get(str(value or "").strip().upper(), 3)


def worst(items):
    return min((sev(i.get("severity")) for i in items))


def reviewers_of(group):
    seen, out = set(), []
    for i in group["items"]:
        r = i["_reviewer"]
        if r not in seen:
            seen.add(r)
            out.append(r)
    return out


def block(label, text, indent="      "):
    if not text:
        return
    body = textwrap.fill(str(text).strip(), width=WRAP,
                         initial_indent=indent + label + ": ",
                         subsequent_indent=indent + " " * (len(label) + 2))
    print(body)


def main():
    if len(sys.argv) != 3:
        die("usage: second-opinion-merge.py MANIFEST.json OUT.json")

    with open(sys.argv[1]) as fh:
        manifest = json.load(fh)

    all_findings, reviewer_rows = [], []
    for entry in manifest:
        verdict, summary, findings, error = extract(entry)
        for f in findings:
            if isinstance(f, dict):
                f["_reviewer"] = entry["reviewer"]
                all_findings.append(f)
        severities = [f.get("severity") for f in findings if isinstance(f, dict)]
        reviewer_rows.append({
            "reviewer": entry["reviewer"],
            "engine": entry.get("engine"),
            "verdict": verdict,
            "summary": summary,
            "count": len(findings),
            "worst": min([sev(s) for s in severities]) if severities else None,
            "normalized": entry.get("normalized", False),
            "duration": entry.get("duration"),
            "tokens": entry.get("usage"),
            "error": error,
        })

    groups = cluster(all_findings)
    groups.sort(key=lambda g: (worst(g["items"]), -len(reviewers_of(g)), g["file"], g["line"]))
    agreed = [g for g in groups if len(reviewers_of(g)) > 1]
    solo = [g for g in groups if len(reviewers_of(g)) == 1]

    live = [r for r in reviewer_rows if not r["error"]]
    print("SECOND OPINION — %d/%d reviewers answered, %d findings, %d agreed"
          % (len(live), len(reviewer_rows), len(groups), len(agreed)))
    print("")
    print("  %-26s %-18s %8s %8s %9s" % ("reviewer", "verdict", "findings", "seconds", "tokens"))
    for r in reviewer_rows:
        if r["error"]:
            print("  %-26s %s" % (r["reviewer"], "FAILED: " + r["error"]))
            continue
        print("  %-26s %-18s %8d %8s %9s%s" % (
            r["reviewer"], r["verdict"] or "-", r["count"],
            ("%.1f" % r["duration"]) if r["duration"] else "-",
            r["tokens"] if r["tokens"] else "-",
            "  transcribed" if r.get("normalized") else ""))
    # A reviewer that approves while reporting a P0 or P1 contradicts itself; its
    # verdict carries no weight, though the findings themselves may still be real.
    for r in reviewer_rows:
        if r["verdict"] == "approve" and r["worst"] is not None and r["worst"] <= 1:
            print("  ! %s approved while reporting a %s — treat its verdict as unreliable."
                  % (r["reviewer"], ["P0", "P1"][r["worst"]]))

    print("")
    for r in reviewer_rows:
        if r["summary"]:
            block(r["reviewer"], r["summary"], indent="  ")

    def render(section, title):
        if not section:
            return
        print("")
        print(title)
        for g in section:
            items = sorted(g["items"], key=lambda i: sev(i.get("severity")))
            lead = items[0]
            names = reviewers_of(g)
            unverified = all(i.get("confidence") == "unverified" for i in items)
            loc = "%s:%d" % (g["file"], g["line"]) if g["line"] else g["file"]
            print("")
            print("  %-3s %s  %s%s" % (str(lead.get("severity") or "?").upper(), loc, lead.get("title", ""),
                                       "  [unverified]" if unverified else ""))
            print("      seen by: %s" % ", ".join(names))
            block("failure", lead.get("failure"))
            block("fix", lead.get("fix"))
            if lead.get("evidence_needed"):
                block("to settle", lead.get("evidence_needed"))
            for extra in items[1:]:
                if extra.get("title") and extra["title"].lower() != (lead.get("title") or "").lower():
                    block("also (%s)" % extra["_reviewer"], extra["title"])

    render(agreed, "AGREED — flagged independently by more than one reviewer")
    render(solo, "SINGLE REVIEWER — weigh these yourself")

    if not groups:
        print("")
        if live:
            print("  No findings. Every reviewer that answered came back clean.")
        else:
            # An empty report from an empty panel is not an approval, and must
            # never be able to read as one.
            print("  NOTHING WAS REVIEWED. Every reviewer failed — see the errors above.")
            print("  This is not an approval; the change is exactly as unreviewed as before.")

    with open(sys.argv[2], "w") as fh:
        json.dump({"reviewers": reviewer_rows, "groups": groups}, fh, indent=2)
    print("")
    print("  merged JSON: %s" % sys.argv[2])

    # A panel where nobody answered must fail loudly: a caller that only checks
    # the exit code would otherwise bank an unreviewed change as reviewed.
    if not live:
        raise SystemExit(3)


if __name__ == "__main__":
    main()
