# AGENTS.md

This file provides guidance to Claude Code when working with code in this repository.

> **Template note.** Replace every `<...>` placeholder with real project values, then
> delete this note. The starterkit ships no Swift stack plugin yet: style is enforced by
> `swift format` with a committed `.swift-format` configuration (start from
> `swift format dump-configuration > .swift-format`), and naming follows the Swift API
> Design Guidelines. This file holds only what is specific to THIS project.

## What this project is

<One paragraph: what the package does and its main flow.>

## Stack

- Swift `<x.y>` with Swift Package Manager; platforms: `<macOS N / iOS N / Linux>`.
- Tests: Swift Testing (`import Testing`, `@Test`, `#expect`).
- Formatting and lint: `swift format` (bundled with the toolchain), configured by
  `.swift-format`.

## Build & run

```bash
make build    # swift build
make test     # swift test
make lint     # swift format lint --strict
make format   # swift format --in-place
make verify   # build + lint + test: the gate before review and commit
```

Targeted runs: `swift test --filter <TestName>`; `swift run <executable>`.

## Layout

| Path | Role |
|------|------|
| `Package.swift` | Package manifest: products, targets, platforms |
| `Sources/<target>/` | Target sources (`@main` entry point for an executable) |
| `Tests/<target>Tests/` | Test target |

<Adjust rows to the real layout. Delete what doesn't exist.>

## Key dependencies

- `<package URL>` — <purpose>

## Deployment

<How this ships: release binary, signed app, notarization, Homebrew tap. Add a
`make deploy` target when it exists.>

## Working agreement

Plan-first pipeline; the canonical procedure is the `pipeline:working-agreement` skill — load it
before starting non-trivial work. Project delta:

- **Gate:** `make verify`
- **Review focus:** standard staged set — see `pipeline:working-agreement`.
- **Branching:** standard — `dev` is the integration branch.
