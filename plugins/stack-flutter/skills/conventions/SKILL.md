---
name: flutter-conventions
description: Flutter/Dart project conventions - forbidden constructs, state management discipline, widget rules, async safety, error-handling contract, and test structure. Load before writing or reviewing any Dart/Flutter code.
paths:
  - "**/*.dart"
  - "**/pubspec.yaml"
---

# Flutter conventions

Project `CLAUDE.md` overrides anything here. These are the defaults for every Flutter repo.

## Forbidden constructs

- No `print` in production code — use a logger (`avoid_print` analyzer rule enforces).
- No `dynamic` outside decoding boundaries; convert to typed models immediately.
- No `!` (null-bang) on values whose non-nullness isn't proven on the prior line.
- No `BuildContext` use across an `await` without a `mounted` check; no `setState` after dispose — guard with `if (!mounted) return`.
- No silently swallowed errors: never `try { ... } catch (_) {}` without logging or a comment explaining why the swallow is correct.

## State management discipline

- **One approach per app** (bloc, riverpod, provider — whatever the project chose in `CLAUDE.md`). Mixing two produces silent double-updates and ghost rebuilds; flag any second approach as a finding.
- Local, view-only state via `setState` is fine; app-level state through the chosen approach only.
- State holders are injected and testable (BLoC → `bloc_test`; Riverpod → `ProviderContainer` overrides).

## Widget & async rules

- Stable widgets in lists get explicit keys (`ValueKey`/`ObjectKey`) to preserve state during reorder/insert.
- Every `Future` is `await`ed or explicitly wrapped in `unawaited(...)` (`dart:async`) to document fire-and-forget intent.
- Prefer `mocktail` over `mockito` — no codegen, plays nicely with null safety.
- `flutter analyze` must pass with zero issues before review.

## Error-handling contract (default pattern)

- A sealed `Failure` hierarchy (`sealed class Failure`) is the **only** mechanism for user-visible error messages, constructed where the error arises (data/domain layer).
- Everything else flows as plain `Exception`/`Error` and is translated to one generic fallback constant at the UI boundary.
- Use-case return type is `Result<T, Failure>` / `Either<Failure, T>` — one library, consistently.
- Every test exercising an error branch asserts: (1) the UI rendered something (no silent failure); (2) the text matches the matched `Failure` case; (3) the text equals the fallback constant for non-`Failure` errors.

## Test structure

**One `group()` per tested unit, one `test()`/`testWidgets()`/`blocTest()` per scenario inside it** — reports group by *what is tested*, not by scenario shape. Do not scatter scenarios across top-level `test()` calls.

- Pure function → one `group` named after the function.
- Method on a class → one `group` per method, named `ClassName.methodName`.
- Widget → one `group` per widget, `testWidgets` per scenario.
- State holder → one `group` per public method, `blocTest` (or equivalent) per scenario.
- Goldens: regenerate (`flutter test --update-goldens`) only for *intentional* UI changes, and say so in the commit body.

## Configuration & secrets

- Compile-time `--dart-define` for secrets and per-flavor URLs; flavors drive different define sets.
- `flutter_dotenv` assets ship inside the bundle — never real secrets there.
- Never read or edit `.env` files; never commit signing key material.
