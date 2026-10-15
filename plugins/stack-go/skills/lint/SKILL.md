---
name: go-lint
description: The mechanical half of Go code review - the canonical .golangci.yml, the ruleguard rules that cover project conventions no upstream linter implements, and the text-level checks for comment and test-scaffolding rules. Load when adopting linting in a Go repo, when adding or changing a review rule, or when deciding whether a new rule belongs in a linter or in a review skill.
---

# Go linting

Review rules split into three tiers by who enforces them. Putting a rule in the
wrong tier is the expensive mistake: a mechanical rule left to a human reviewer
is checked unreliably and re-derived on every pass, and a judgment call forced
into a linter fires on correct code until someone disables it.

| Tier | Enforced by | Nature of the rule |
|---|---|---|
| 1 | an upstream linter | deterministic, already solved by someone else |
| 2 | `gorules/rules.go` (ruleguard) or `lint-checks.sh` | deterministic, local pattern, no upstream implementation |
| 3 | the reviewer skills | needs judgment, context, or flow analysis |

## Adding a rule: decide the tier first

Before writing a rule into any review skill, answer in order. The first "yes"
decides where it goes.

1. **Does an upstream linter already do it?** Search the golangci-lint linter
   list. Roughly sixty rules that read like house style — declaration order
   (`funcorder`), godoc (`godoclint`), mixed receivers (`recvcheck`),
   `t.Context()` (`usetesting`), context in a struct (`containedctx`) — are
   already implemented. Enable it; do not restate it in a skill.
2. **Is it a local AST pattern?** Something matchable by looking at one
   expression, statement, or block without knowing what happens elsewhere in
   the function. Write it in `gorules/rules.go`.
3. **Is it a text pattern?** Comments and absences of declarations are
   invisible to AST tooling. Write it in `lint-checks.sh`.
4. **Otherwise it needs judgment.** It belongs in a reviewer skill — and the
   skill entry must say why it cannot be mechanised, so nobody re-litigates it.

A rule that fails to distinguish correct code from incorrect code is not a
tier-2 rule with rough edges; it is noise, and noise trains people to skim the
whole report. Delete it and move it to tier 3.

## Adopting this in a repo

1. Copy `assets/golangci.yml` to `.golangci.yml` at the repo root and fill in
   the two blocks marked `PROJECT`.
2. Copy `assets/rules.go` to `gorules/rules.go`, then
   `go get github.com/quasilyte/go-ruleguard/dsl`. The file carries a
   `//go:build ruleguard` tag so it never enters a binary, but the dependency
   must be in `go.mod` or the rules fail to typecheck. `go mod tidy` keeps it:
   custom build tags are still considered when resolving imports.
3. Copy `assets/lint-checks.sh` to `scripts/lint-checks.sh`.
4. Wire `make lint` to run `golangci-lint run ./...` then `scripts/lint-checks.sh`.
5. Add a CI job with the linter version pinned. An unpinned linter turns a
   release of somebody else's tool into a red build on an untouched branch.
6. On an existing codebase, adopt a baseline (`--new-from-rev`) so the standing
   findings do not block merges. A wall of pre-existing violations that nobody
   can clear in one sitting gets the whole gate switched off within a week.

## Operational traps

- **The ruleguard cache is not keyed on the rules file.** Editing
  `gorules/rules.go` changes no analysed source, so golangci-lint replays the
  cached result and your edit appears to do nothing. Run
  `golangci-lint cache clean` after every rules change. This has cost real
  debugging time; do not rediscover it.
- **`failOn: all` is mandatory** in the ruleguard settings. Without it a typo
  in the rules file silently disables every custom rule and the run stays
  green.
- **Keep the linter version identical across machines and CI.** Different
  versions disagree about what is a finding, which turns a code review into an
  argument about tooling.

## Known gaps

Real rules that this tooling cannot enforce today. They stay manual-review
items, and each is a candidate for a `go/analysis` analyzer shipped through the
golangci-lint module plugin system, which would also remove the per-repo
`gorules/` copies.

- **pgx is invisible to the SQL linters.** `rowserrcheck` and `sqlclosecheck`
  only understand `database/sql`. Any repository layer built on
  `jackc/pgx` gets no coverage at all: a `rows.Next()` loop with no
  `rows.Err()` check afterwards returns a silently truncated result set with a
  nil error. Check every iteration by hand.
- **A type-erasing defer wrapper blinds the resource linters.**
  `defer func(c interface{ Close() }) { c.Close() }(rows)` closes correctly but
  `sqlclosecheck` reports a leak, and the inverse case would go unreported.
  Prefer `defer rows.Close()`.
- **Log-and-wrap-and-return.** The ruleguard rule catches logging and returning
  the same bare error. Logging and returning a *wrapped* error is sometimes
  deliberate — an operational breadcrumb at a half-state boundary — so it is
  left to the reviewer.
- **Unbounded fan-out.** Whether an `errgroup` is bounded depends on a
  `SetLimit` call elsewhere in the function.
