# Claude Code Scala Starter

A project-agnostic starter for Scala (ZIO) services that work with Claude Code out
of the box. Drop the template into a fresh Scala project, fill in the `<...>`
placeholders in `CLAUDE.md`, and you get:

- A `CLAUDE.md` documenting architecture, error handling (`DomainError` typed `E`
  channel), forbidden constructs, planning workflow, and the Scala-specific
  **Test Structure** rule built around `suite(...)` + `test(...)`.
- Four ready-to-use subagents in `.claude/agents/`:
  - `scala-architect` — planning and decomposition
  - `scala-engineer` — implementation
  - `scala-reviewer` — review and verdicts (runs 3× in parallel with distinct lenses)
  - `scala-testdoctor` — failing-test triage

  The reviewer stage is a standard **3-reviewer fan-out** with lenses A (correctness
  & tests), B (security & ops), and C (performance & architecture). The orchestrator
  synthesises the three reports into a single punch list. See `CLAUDE.md` →
  **Agent Pipeline**.
- A `.claude/settings.json` with a sensible default permission allowlist for Scala
  (`sbt compile`, `sbt test`, `sbt scalafmtCheckAll`, `scala-cli`, `coursier`,
  common git, etc.) and a strict deny list (`.env`, `.idea`, destructive ops).
- Two slash commands in `.claude/commands/`:
  - `/new-plan <slug>` — scaffolds `plans/NNN-slug.md` from the documented template
  - `/complete-plan <NNN|slug>` — moves a plan to `plans/completed/YYMMDD.NNNN.slug.md`
    after `sbt scalafmtCheckAll` + `sbt compile` + `sbt test` pass
- Per-agent memory directories in `.claude/agent-memory/<agent-name>/` with a README
  explaining the commit policy.
- A `plans/` directory with the lifecycle (`active` → `completed/` → `history/`)
  wired in, plus one worked example plan under `plans/completed/`.

## Install

From the starter repo root:

```bash
./install.sh scala /path/to/your-project
```

This copies `CLAUDE.md`, the entire `.claude/` directory, and the `plans/` skeleton
into the target project. The script refuses to overwrite an existing `CLAUDE.md` or
`.claude/` unless you pass `--force`.

Manual install (if you prefer):

```bash
cp scala/CLAUDE.md /path/to/your-project/CLAUDE.md
cp -R scala/.claude /path/to/your-project/.claude
mkdir -p /path/to/your-project/plans/{completed,history}
```

After install, open `CLAUDE.md` and replace every `<...>` placeholder with the real
values for your project (Scala version, JDK, effect system, layer responsibilities,
service pattern, persistence library, configuration source).

## Key Scala-specific characteristics

- **ZIO 2 by default.** The error-handling contract uses the `E` channel for typed
  domain errors and treats unrecoverable failures as defects (`ZIO.die`/`orDie`).
  Cats Effect 3 is also supported — pick one and document it in `CLAUDE.md`.
- **`suite(...)` is the subtest equivalent.** `zio-test`'s `suite(...)` nests
  scenarios; the rule mirrors Go's `t.Run`: one `suite(...)` per tested unit, one
  `test(...)` per scenario inside it.
- **Layer discipline.** Services declare requirements via the `R` channel; only the
  composition root constructs `ZLayer`s. Downstream code never builds layers itself.
- **Forbidden constructs.** No `throw` in effectful code, no `.get` on
  `Option`/`Either`/`Try`, no `var` outside tight local scopes, no `Await.result`
  on a `Future`, no non-exhaustive pattern matches (`-Wunused` / `-Xfatal-warnings`
  enabled).
- **scalafmt + scalafix gate completion.** A plan can't be marked completed until
  `sbt scalafmtCheckAll` and `sbt "scalafixAll --check"` pass alongside `sbt test`.
- **Mocking via `zio-mock` or hand-written test `ZLayer`s.** Reflective mocking
  frameworks are discouraged.

## Agent memory

Agents write persistent memory to `.claude/agent-memory/<agent-name>/`. These files
are project-scoped and intended to be committed — they capture user preferences,
non-obvious feedback, ongoing project state, and pointers to external resources.
The directories ship with `.gitkeep` placeholders; nothing needs to be created up
front.

## Local overrides

Personal permission overrides go in `.claude/settings.local.json` (committed-ignored
by the starter's `.gitignore`). The committed `.claude/settings.json` is the team
default — keep it conservative and use the local file for per-developer tweaks.
