# Review

A `review` (see the glossary) runs in three steps, in this order:

1. **Parallel reviewers** — three `pipeline:reviewer` agents launched in one message, one
   each for correctness and tests, security and operations, and architecture and
   performance.
2. **Standards audit** — the `code-standards-auditor` agent checks the change against my
   `R#` rules.
3. **External reviewers** — `codex` on `sol` (`ai-codex`), only when the conditions at the
   end of this file hold. Gemini (`g-pro`, through OpenRouter) is no external reviewer; it is
   the extra opinion `second-opinion.sh` adds when a blocker is contested.

- Commit before every reviewer — before launching the parallel reviewers and before the
  standards audit; each holds write tools and may check out other revisions, wiping
  uncommitted work.
- Where this reference and `pipeline:working-agreement` differ, this reference wins on
  exactly two clauses; everything else in the working agreement stands:
  - **Commit cadence.** The working agreement's "Commit" step and "Branching" section ask
    for one commit per plan. Here, a commit lands before every reviewer; the intermediate
    commits are fine and are squashed into the plan's single commit at completion.
  - **Standards-audit routing.** The working agreement's "Severity" section and
    "Author-standards pass" apply the audit's grooming in-cycle at every severity. Here,
    audit findings P0–P2 are fixed in the same pass, and P3 and "Worth a look" go to
    `.agents/plans/backlog/` (next bullet).
- The standards audit runs only once the parallel reviewers' blockers are fixed and
  re-checked and their other findings are filed. Its findings: P0–P2 fixed in the same
  pass; P3 and "Worth a look" → `.agents/plans/backlog/`, overriding the auditor's own
  tracker routing. The audit is also the standalone gate over my `R#` rules, runnable on
  demand outside a review.
- An uncontested P0 — a confirmed leaked secret, a red gate — is fixed in the same pass
  without asking, then re-checked. Consensus decides only contested blockers: when a
  finding's blocking status is genuinely disputable, take your own position, then run
  `second-opinion.sh` with the change as `--target` and the finding as
  `--question` (`--help` carries the rest); it merges verdicts from reviewers outside the
  Anthropic family into one ranked report. Escalate one step at a time:
  1. `sol` and `opus` agree — no external call;
  2. they disagree — `--tier 2` (`g-pro`, `grok`);
  3. the cost of a wrong call is high (security, architecture, `R#` rules) — `--tier 3`
     (adds `muse`);
  4. still ambiguous after step 3 — `--tier 4` (adds `astra`) plus `fable` through
     `claude -p --model fable`. Reviewers get assembled material only, never a
  shell in the repository. Consensus "blocking" → fix, re-check. Failed consensus →
  reaches me with each position stated.
- Every non-blocking finding the rules above don't fix in-pass — from the parallel
  reviewers, standards-audit P3, `codex`, or a consensus that lands "not
  blocking" — becomes a `.agents/plans/backlog/` entry with its severity; the cycle never
  stalls on one and none is dropped.
- External calls happen only if one of these holds: I asked for a `review` by name (all
  three steps above, keeping every rule here); I asked for a `second-opinion` (`codex` on
  `sol` only, since 2026-10-19 in place of `codex` + `gemini`); or a blocker is contested
  (`second-opinion.sh`, above). Otherwise no external call. In a requested `review` a `codex` blocker is already
  cross-family: uncontested → fix; contested → reaches me with each position stated; no
  second external round. A blocker from the parallel reviewers contested inside that
  review rides on the same external pass, not a separate `second-opinion.sh` run; the
  consensus rule above decides it.
