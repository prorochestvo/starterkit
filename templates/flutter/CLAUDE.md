# CLAUDE.md

This file provides guidance to Claude Code when working with code in this repository.

> **Template note.** Replace every `<...>` placeholder with real project values, then
> delete this note. Conventions (forbidden constructs, state management discipline,
> test structure, error contract) come from the `stack-flutter` plugin skill — this
> file holds only what is specific to THIS project.

## What this app is

<One paragraph: what the app does and its main flow.>

## Build & run

Standard Flutter CLI (`flutter pub get|run|build|clean|analyze`, `dart format .`).
Non-obvious gates:

- `dart format --set-exit-if-changed .` — CI formatting gate.
- `flutter analyze` — zero issues required.
- `flutter test [--coverage] [--name "<...>"]` — unit/widget tests.
- `flutter test --update-goldens` — only after an *intentional* UI change.
- Codegen (only if `build_runner` is used): `dart run build_runner build --delete-conflicting-outputs`.

## Versions

- Flutter: `<x.y.z>` (stable) · Dart: `<x.y.z>` · Min Android SDK: `<21+>` · Min iOS: `<13.0+>`

## Architecture

| Layer | Location | Role |
|-------|----------|------|
| Entry point | `lib/main.dart` | Bootstrap, dependency wiring |
| Presentation | `lib/features/<feature>/presentation/` | Widgets, screens, state holders |
| Domain | `lib/features/<feature>/domain/` | Entities, value objects, use cases |
| Data | `lib/features/<feature>/data/` | Repositories, data sources, DTOs |
| Core | `lib/core/` | Error types, theming, routing |

- State management: `<bloc | riverpod | provider>` — one approach, no mixing.
- Routing: `<go_router | auto_route>`; routes defined in `<path>`.
- Networking: `<dio | http>`; base URL from `<config source>`; serialization `<json_serializable | freezed>`.
- Persistence: `<drift | isar | hive | shared_preferences | secure_storage>`.
- Config: `--dart-define` per flavor `<list the defines>`.

## Key dependencies

- `<package>` — <purpose>

## Build flavors

<Flavor matrix (dev/staging/prod), entry points per flavor, how to run each. Delete if single-flavor.>

## Working agreement

All non-trivial work follows the plan-first pipeline:

1. **Plan** — the `architect` agent writes `plans/NNN-slug.md` (create via the
   `pipeline:new-plan` skill). No source edits before a plan exists.
2. **Implement** — the `engineer` agent executes the plan's tasks with tests.
3. **Review** — three `reviewer` agents launched in parallel in ONE message, each
   prompt naming its lens (A: correctness & tests, B: security & operations,
   C: performance & architecture) and the changed files. Full three-lens fan-out is
   mandatory on the first review; the post-fix re-review is ONE solo reviewer scoped
   to the changed lines.
4. **Gate** — `flutter analyze` + `flutter test` must be green before review; a red
   tree goes to the `testdoctor` agent first, at any stage.
5. **Complete** — the orchestrator merges the three reports, deduplicates, resolves
   conflicting verdicts (naming what was rejected and why; the user has final say).
   P0/P1 findings loop back to the engineer. Only when every P0/P1 is fixed or
   explicitly accepted: move the plan via the `pipeline:complete-plan` skill.

Plans live in `plans/` (active), `plans/completed/` (shipped, `YYMMDD.NNNN.slug.md`),
`plans/history/` (abandoned/superseded). One plan per concern.
