#!/usr/bin/env python3
"""Transcribe a prose review into the findings schema.

Models honour --json-schema unevenly: Gemini returns the requested object, other
models answer with a markdown table no matter what the schema says. Dropping
those reviewers would narrow the panel to whoever is best behaved, and treating
their output as empty would report silence as approval — the worse of the two.
So a prose answer gets one cheap transcription pass instead.

  check FILE ENGINE          exit 1 if already structured; else print the prose
  apply FILE ENGINE NORMOUT  fold the transcription back into FILE
"""

import json
import sys


def load(path):
    try:
        with open(path) as fh:
            return fh.read()
    except IOError:
        return ""


def strip_fence(text):
    """Unwrap a ```json fence. Duplicated in second-opinion-merge.py: two sibling
    scripts with no package between them, and a model that fences its answer must
    not be sent through a transcription pass it does not need."""
    text = text.strip()
    if text.startswith("```"):
        parts = text.split("```")
        if len(parts) > 1:
            text = parts[1]
            if text.startswith("json"):
                text = text[4:]
            text = text.strip()
    return text


def structured_of(raw, engine):
    """Return the findings object already present in a reviewer's output, or None."""
    if not raw.strip():
        return None
    if engine == "agy":
        try:
            envelope = json.loads(raw)
        except ValueError:
            return None
        payload = envelope.get("structured_output")
    else:
        try:
            payload = json.loads(strip_fence(raw))
        except ValueError:
            return None
    if isinstance(payload, dict) and isinstance(payload.get("findings"), list):
        return payload
    return None


def prose_of(raw, engine):
    if engine == "agy":
        try:
            return json.loads(raw).get("response", "") or ""
        except ValueError:
            return raw
    return raw


def main():
    if len(sys.argv) < 4:
        sys.stderr.write(__doc__)
        raise SystemExit(2)

    mode, path, engine = sys.argv[1], sys.argv[2], sys.argv[3]
    raw = load(path)

    if mode == "check":
        if structured_of(raw, engine) is not None:
            raise SystemExit(1)
        prose = prose_of(raw, engine).strip()
        if not prose:
            raise SystemExit(1)  # nothing was produced; not a transcription problem
        sys.stdout.write(prose)
        raise SystemExit(0)

    if mode != "apply":
        raise SystemExit(2)

    def reject(reason):
        """Stamp the reviewer as failed and leave nothing behind to misread.

        Exiting alone is not enough: the untouched prose stays on disk, and a
        refusal that quotes an example schema would be mined out of it downstream
        and reported as an approval with no findings. Every way this function can
        fail ends here.
        """
        with open(path, "w") as fh:
            json.dump({"status": "ERROR", "error": "transcription rejected: %s" % reason}, fh)
        sys.stderr.write("not a review: %s\n" % reason)
        raise SystemExit(1)

    payload = structured_of(load(sys.argv[4]), "agy")
    if payload is None:
        reject("the transcriber produced no usable output")

    # A refusal, an apology or a truncation notice transcribes into a perfectly
    # well-formed object with no findings, which the report would then present as
    # a clean review. The transcriber is asked to say when the text was not a
    # review at all, and that answer is a failure, not an approval.
    # Fail closed. Schema enforcement is a per-model courtesy, so is_review may
    # come back absent, or as the string "false" — and every one of those cases
    # must be a failure rather than a review with nothing in it.
    claim = payload.get("is_review")
    if not (claim is True or str(claim).strip().lower() == "true"):
        reject(payload.get("reason") or "is_review not asserted")
    for key in ("is_review", "reason"):
        payload.pop(key, None)

    payload["_normalized"] = True

    if engine == "agy":
        try:
            envelope = json.loads(raw)
        except ValueError:
            envelope = {"status": "SUCCESS"}
        # Keep the reviewer's own cost and timing; only its shape was borrowed.
        envelope["structured_output"] = payload
        out = json.dumps(envelope)
    else:
        out = json.dumps(payload)

    with open(path, "w") as fh:
        fh.write(out)
    raise SystemExit(0)


if __name__ == "__main__":
    main()
