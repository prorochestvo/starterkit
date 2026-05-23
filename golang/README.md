# Claude Code Go Starter

A project-agnostic starter for Go services that work with Claude Code out of the
box. Drop the template into a fresh Go project, fill in the `<...>` placeholders in
`CLAUDE.md`, and you get:

- A `CLAUDE.md` documenting architecture, error handling (`PublicError` pattern),
  forbidden imports / constructs, planning workflow, and the standard
  **3-reviewer fan-out** agent pipeline (lenses A/B/C: correctness & tests,
  security & ops, performance & architecture).
- Four ready-to-use subagents in `.claude/agents/`:
  - `gocode-architect` — planning and decomposition
  - `gocode-engineer` — implementation
  - `gocode-reviewer` — review and verdicts (runs 3× in parallel with distinct lenses)
  - `gocode-testdoctor` — failing-test triage
- A `.claude/settings.json` with a sensible default permission allowlist for Go
  (`go test`, `go build`, `go vet`, `make test`, `gofmt`, `golangci-lint`, common
  git, etc.) and a strict deny list (`.env`, `.idea`, destructive ops).
- Two slash commands in `.claude/commands/`:
  - `/new-plan <slug>` — scaffolds `plans/NNN-slug.md` from the documented template
  - `/complete-plan <NNN|slug>` — moves a plan to `plans/completed/YYMMDD.NNNN.slug.md`
    after `make test` passes
- Per-agent memory directories in `.claude/agent-memory/<agent-name>/` with a README
  explaining the commit policy.
- A `plans/` directory with the lifecycle (`active` → `completed/` → `history/`)
  wired in, plus one worked example plan under `plans/completed/`.

## Install

From the starter repo root:

```bash
./install.sh golang /path/to/your-project
```

This copies `CLAUDE.md`, the entire `.claude/` directory, and the `plans/` skeleton
into the target project. The script refuses to overwrite an existing `CLAUDE.md` or
`.claude/` unless you pass `--force`.

Manual install (if you prefer):

```bash
cp golang/CLAUDE.md /path/to/your-project/CLAUDE.md
cp -R golang/.claude /path/to/your-project/.claude
mkdir -p /path/to/your-project/plans/{completed,history}
```

After install, open `CLAUDE.md` and replace every `<...>` placeholder with the real
values for your project (Go version, module path, layer responsibilities, HTTP
routes, database engine, key dependencies, env vars, deployment).

## Key Go-specific characteristics

- **`CGO_ENABLED=0` by default.** Build and test commands include the flag
  explicitly. Adjust if your project legitimately needs CGO.
- **`PublicError` for user-facing errors.** A dedicated wrapper type carries safe,
  human-readable messages; everything else is a plain `error` translated to a
  generic fallback at the controller boundary.
- **One `Test*` per method, scenarios as subtests.** `TestEncode` with
  `t.Run("description", ...)` for each scenario — never `TestEncode_Empty`,
  `TestEncode_Unicode`, etc.
- **Embedded migrations + dedicated migrator.** Schema lives in `migrations/*.sql`
  exposed via `//go:embed`; `cmd/migrator` is the only thing that mutates schema;
  service binaries verify schema is current at startup and `log.Fatalf` if not.
- **Build outputs in `./build/`, scratch in `./tmp/`, logs in `./logs/`.** Only
  these three directories are gitignored at repo root — keep stray binaries out.
- **3-reviewer fan-out.** The reviewer stage launches three `gocode-reviewer` agents
  in parallel, one per lens (A: correctness & tests, B: security & ops, C: performance
  & architecture). The orchestrator synthesises the reports into a single punch list.
  See `CLAUDE.md` → **Agent Pipeline**.

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
