# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

> **Template note.** This is a project-agnostic Flutter starter. Replace the `<...>`
> placeholders and the example sections below with the real values for your project.
> Anything inside a `<...>` is a marker that must be filled in or removed before the
> file is considered complete.

## Build & Run Commands

```bash
flutter pub get               # Install dependencies
flutter run                   # Run on the connected device / default simulator
flutter run -d <device-id>    # Run on a specific device (`flutter devices` to list)
flutter build apk             # Build Android APK
flutter build appbundle       # Build Android App Bundle (Play Store)
flutter build ios             # Build iOS (requires Xcode + signing)
flutter build web             # Build web bundle
flutter clean                 # Remove build artifacts
flutter analyze               # Run the static analyzer (lints)
dart format .                 # Format all Dart sources
dart format --set-exit-if-changed . # Verify formatting (CI-friendly)
```

Test commands:
```bash
flutter test                              # Run all unit + widget tests
flutter test test/path/to/file_test.dart  # Run a single test file
flutter test --name "<group or test name>" # Filter by group/test name
flutter test --coverage                   # Generate coverage/lcov.info
flutter test --update-goldens             # Regenerate golden files (after intentional UI change)
flutter test integration_test/            # Run integration tests (driver-based)
```

Code generation (only if the project uses `build_runner` for `freezed` / `json_serializable` / `riverpod_generator` / `mocktail_codegen`):
```bash
dart run build_runner build --delete-conflicting-outputs
dart run build_runner watch --delete-conflicting-outputs
```

## Architecture Overview

<One-paragraph description of what this app does and its main flow.>

### Flutter / Dart Versions

- Flutter: `<x.y.z>` (channel: stable)
- Dart: `<x.y.z>` (matched to the Flutter version)
- Min Android SDK: `<21+>`
- Min iOS: `<13.0+>`

### Layer Responsibilities

Replace the rows below with the real layout of your project. The example below uses a
common feature-first / clean-architecture-ish layout — keep, edit, or remove rows as
needed.

| Layer | Location | Role |
|-------|----------|------|
| Entry point | `lib/main.dart` | App bootstrap, dependency wiring |
| Presentation | `lib/features/<feature>/presentation/` | Widgets, screens, state holders |
| Domain | `lib/features/<feature>/domain/` | Pure entities, value objects, use cases |
| Data | `lib/features/<feature>/data/` | Repositories, data sources, DTOs, mappers |
| Core / shared | `lib/core/` | Shared utilities, error types, theming, routing |

### State Management

Pick one and stick with it. Mixing two approaches in the same app produces silent
double-updates and ghost rebuilds.

- **`<bloc | flutter_bloc | riverpod | provider | get_it + ChangeNotifier>`** — chosen approach
- Conventions: where state holders live, how they're injected, how they're tested
  (BLoC → `bloc_test`; Riverpod → `ProviderContainer` overrides; etc.)

### Routing

- Router: `<go_router | auto_route | Navigator 1.0>`
- Route definitions: `<path>`
- Deep-link handling: `<...>`

### Networking

- HTTP client: `<dio | http | chopper>`
- API base URL: from `<config source>`
- Authentication: `<scheme>`
- Serialization: `<json_serializable | freezed | dart:convert + manual>`

### Persistence / Local Storage

- Database / KV: `<sqflite | drift | isar | hive | shared_preferences | secure_storage>`
- Migrations: `<approach>`

### Environment / Configuration

Flutter has no built-in `.env` mechanism — pick an approach and document it. Common
choices:

- **Compile-time `--dart-define`** — recommended for secrets and per-flavor URLs.
  Read in code with `String.fromEnvironment('KEY')`.
- **Flavors** — Android `productFlavors` / iOS configurations driving different
  `--dart-define` sets.
- **`flutter_dotenv`** — reads a `.env` asset; convenient but the file ships in the
  bundle, so never put real secrets there.

> Never read or edit `.env` files. Never commit signed key material.

### Key Dependencies

List third-party packages that materially shape the codebase. Example shape:

- `<package_name>` — purpose
- ...

### Build Variants / Flavors

Document the flavor matrix if the app has more than one (`dev`, `staging`, `prod`).
Include the entry-point file each flavor uses (`lib/main_dev.dart`, etc.) and how to
run/build each.

### Linting

- Lint package: `<flutter_lints | very_good_analysis | lints>`
- Custom rules in `analysis_options.yaml`
- `flutter analyze` must pass with zero issues before a PR is approved.

## Error Handling

Define the project's error-handling contract here. The example below describes a
common pattern of separating user-facing errors from internal failures — keep,
adapt, or replace it.

### Sealed `Failure` / `AppError` — user-facing errors (example pattern)

A sealed hierarchy (commonly `Failure` or `AppError`, often built with `freezed`'s
`sealed class`) is the mechanism for surfacing safe, human-readable messages to end
users. Any error that is **safe to show** is constructed from this hierarchy at the
point where the error is created (typically in the data or domain layer). All other
failures (network down, parse error, unexpected null) flow as plain `Exception` /
`Error` and are translated to a generic fallback at the boundary.

#### Defining the failure type

```dart
// lib/core/error/failure.dart
sealed class Failure {
  const Failure();
}

final class InvalidInput extends Failure {
  const InvalidInput(this.message);
  final String message;
}

final class NotFound extends Failure {
  const NotFound(this.id);
  final String id;
}

final class NetworkUnavailable extends Failure {
  const NetworkUnavailable();
}
```

#### Returning failures from a use case

Use `Result`-style return types or `Either<Failure, T>` from `dartz` / `fpdart`.
Pick one and stick with it.

```dart
Future<Result<User, Failure>> getUser(String id) async {
  try {
    final user = await _repo.findById(id);
    if (user == null) return Result.err(NotFound(id));
    return Result.ok(user);
  } on SocketException {
    return Result.err(const NetworkUnavailable());
  }
  // any other exception escapes and is handled at the boundary as fallback
}
```

#### Rendering failures in the UI

The presentation layer pattern-matches on `Failure` and renders an appropriate
message; everything else gets the fallback constant.

```dart
const errFallbackMessage = 'Something went wrong. Try again later.';

String render(Failure f) => switch (f) {
  InvalidInput(message: final m) => m,
  NotFound() => 'Not found.',
  NetworkUnavailable() => 'No internet connection.',
};
```

### Testing the error path

Every widget / state-holder test that exercises an error branch **must** assert:

1. That the UI actually rendered something (no silent failure).
2. That the rendered text equals the message derived from the matched `Failure` case.
3. That the rendered text equals the fallback constant when the underlying exception
   is not a `Failure`.

## Constraints

Replace this section with the real constraints of your project. The list below is a
reasonable default for a modern Flutter app — keep what applies, drop what doesn't,
add what's missing.

- **Forbidden constructs**:
  - No `print` in production code (use a logger). The analyzer's `avoid_print` rule
    enforces this.
  - No `dynamic` outside of decoding boundaries; convert to typed models immediately.
  - No `!` (null-bang) on values whose nullability isn't proven on the prior line.
  - No `BuildContext` use across an `await` without a `mounted` check.
  - No `setState` calls after `dispose` — guard with `if (!mounted) return`.
- **State management**: only the chosen approach (see Architecture). Mixing
  `setState` for app-level state with BLoC/Riverpod is forbidden; local widget state
  via `setState` for view-only concerns is fine.
- **Mocking**: prefer `mocktail` over `mockito`. `mocktail` requires no code
  generation, plays nicely with null safety, and is the de-facto standard for new
  Flutter codebases.
- **Widget keys**: stable widgets in lists must have explicit keys (`ValueKey`,
  `ObjectKey`) to keep state during reorder/insert.
- **Async safety**: every `async` function returning a `Future<T>` is `await`ed or
  explicitly assigned `unawaited(...)` from `dart:async` to document the
  fire-and-forget intent.
- **No silently swallowed errors**: never `try { ... } catch (_) {}` without logging
  or a comment explaining why the swallow is correct.

## Test Structure

Flutter / Dart has direct support for grouping tests via the `group()` function from
`package:test` (re-exported by `flutter_test`). This is the closest analog to Go's
`t.Run` subtests, and the rule is the same: **one `group(...)` per tested unit, one
`test(...)` per scenario inside it.**

### Unit tests — one `group` per tested method/class

```dart
// test/utils/encoder_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/utils/encoder.dart';

void main() {
  group('Encoder.encode', () {
    test('returns empty string for empty input', () {
      expect(Encoder.encode(''), '');
    });

    test('preserves unicode', () {
      expect(Encoder.encode('café'), 'café');
    });

    test('throws on invalid byte', () {
      expect(() => Encoder.encode('\uD800'), throwsArgumentError);
    });
  });
}
```

Do **not** create separate top-level files or separate top-level `test()` calls per
scenario. All scenarios for the same method live inside a single `group`. For
multiple methods on the same class, use one `group` per method:

```dart
void main() {
  group('User.validate', () {
    test('accepts valid email', () { /* ... */ });
    test('rejects malformed email', () { /* ... */ });
  });

  group('User.updateName', () {
    test('updates non-empty name', () { /* ... */ });
    test('rejects empty name', () { /* ... */ });
  });
}
```

### Widget tests — `testWidgets` inside a `group`

```dart
void main() {
  group('LoginScreen', () {
    testWidgets('shows error when email is invalid', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: LoginScreen()));
      await tester.enterText(find.byType(TextField).first, 'not-an-email');
      await tester.tap(find.byType(ElevatedButton));
      await tester.pump();
      expect(find.text('Invalid email'), findsOneWidget);
    });

    testWidgets('navigates on success', (tester) async {
      // ...
    });
  });
}
```

### BLoC / Cubit tests — `blocTest` inside a `group`

```dart
void main() {
  group('AuthCubit.login', () {
    blocTest<AuthCubit, AuthState>(
      'emits [loading, authenticated] on valid credentials',
      build: () => AuthCubit(authRepo),
      act: (cubit) => cubit.login('a@b.c', 'pw'),
      expect: () => [const AuthLoading(), const AuthAuthenticated()],
    );

    blocTest<AuthCubit, AuthState>(
      'emits [loading, error] on invalid credentials',
      build: () => AuthCubit(authRepo),
      act: (cubit) => cubit.login('a@b.c', 'wrong'),
      expect: () => [const AuthLoading(), const AuthError('Invalid')],
    );
  });
}
```

### Golden tests — one `group` per widget

```dart
void main() {
  group('PrimaryButton golden', () {
    testWidgets('default state', (tester) async {
      await tester.pumpWidget(const PrimaryButton(label: 'Save'));
      await expectLater(
        find.byType(PrimaryButton),
        matchesGoldenFile('primary_button_default.png'),
      );
    });

    testWidgets('disabled state', (tester) async {
      // ...
    });
  });
}
```

### What "one group per tested unit" means

- **Pure function** — one `group` named after the function.
- **Method on a class** — one `group` per method, named `<ClassName>.<methodName>`.
- **Widget** — one `group` per widget, with `testWidgets` per scenario.
- **State holder** (Cubit/Bloc/Notifier) — one `group` per public method, with
  `blocTest` (or equivalent) per scenario.

The rule exists so that test reports group by *what is being tested*, not by
*scenario shape*.

## Planning Workflow

All non-trivial work is tracked as a Markdown plan file before implementation begins.

### Directory layout

```
plans/
├── NNN-task-slug.md     # active / in-progress plans (e.g. 001-fix-auth.md)
├── completed/           # plans for fully shipped tasks (e.g. 260422.0001.fix-auth.md)
└── history/             # archived / cancelled plans
```

### File naming

- **Active plans (`plans/`)** — zero-padded sequential index + kebab-case slug:
  `NNN-description.md` (e.g. `001-fix-login-validation.md`, `002-add-pull-to-refresh.md`).
  Pick the next number by checking the highest existing prefix across `plans/`,
  `plans/completed/`, and `plans/history/`.

- **Completed plans (`plans/completed/`)** — date prefix + zero-padded daily index
  (4 digits) + slug: `YYMMDD.NNNN.description.md`
  (e.g. `260422.0001.fix-login-validation.md`). `NNNN` resets to `0001` each day and
  increments for each additional completion on that day.

- **Archived plans (`plans/history/`)** — keep the original `NNN-` filename from `plans/`.

### Lifecycle

1. **Create** — before touching code, produce a plan file in `plans/` using the
   `NNN-slug.md` naming convention described above.
2. **Implement** — work through the tasks defined in the plan. The plan file stays in
   `plans/` while work is in progress.
3. **Complete** — once every acceptance criterion is met and `flutter test` +
   `flutter analyze` pass, rename and move the file to `plans/completed/`:
   ```bash
   mv plans/001-fix-auth.md plans/completed/260422.0001.fix-auth.md
   ```
4. **Archive** — if a plan is abandoned or superseded without being fully implemented,
   or if intermediate data / task execution logs need to be saved, move it to
   `plans/history/` instead.

### Plan file format

Every plan file follows this structure:

```markdown
# Task Breakdown

## Overview
## Assumptions
## Tasks
### Task N: <Title>
- Description:
- Acceptance Criteria:
- Pitfalls & edge cases:
- Complexity: Easy / Medium / Hard
## Execution Order
## Risks
## Trade-offs
```

### Rules

- **One plan per concern.** Don't bundle unrelated changes in a single plan file.
- **Plan before code.** Claude must create (or confirm an existing) plan file before
  writing or modifying any source files.
- **Keep plans honest.** If implementation diverges from the plan, update the plan
  file before moving it to `completed/`.
- **Slug matches intent.** `002-add-pull-to-refresh.md`,
  `003-migrate-provider-to-riverpod.md`, not `004-task.md`.

## Agent Pipeline

All non-trivial tasks follow a three-stage pipeline using specialized agents. The
review stage fans out to **three `flutter-reviewer` instances running in parallel**,
each with a distinct lens. A separate `flutter-testdoctor` agent is invoked
on-demand whenever tests fail, at any stage.

```
User describes task
    ↓
1. flutter-architect
    → Creates plan file at plans/NNN-slug.md (see Planning Workflow)
    ↓
2. flutter-engineer
    → Implements the tasks defined in the plan
    ↓
3. flutter-reviewer × 3 (run in parallel — single message, three tool calls)
    Lens A: correctness & tests — bugs, races, edge cases, null-safety
            holes, error paths, lifecycle/disposal, test coverage,
            test structure (one group per unit), scenario completeness
    Lens B: security & operations — input validation, auth boundaries,
            secrets handling, injection / XSS, observability (logs,
            crash reporting), log volume, accessibility, platform
            permissions, operator/support UX
    Lens C: performance & architecture — rebuild scoping, `const`
            usage, build-method work, isolate boundaries, memory/image
            handling, layer boundaries, dependency direction, public
            widget/API contracts (breaking changes), state-management
            discipline
    ↓
   Orchestrator synthesises all three reports, deduplicates findings,
   resolves conflicts (e.g. one reviewer flags as P0 what another
   accepts as a trade-off), and presents the merged punch list to the user.
    ↓
  ❌ P0/P1 found?  → Back to flutter-engineer with the consolidated findings.
                             After fix, run ONE targeted reviewer pass on the changed
                             lines (not all 3 again) before re-approval.
  ⚠️  Tests failing?        → flutter-testdoctor diagnoses and patches, then rerun the
                             targeted reviewer pass.
  ✅ All three approve?     → Orchestrator moves the plan: mv plans/NNN-slug.md
                             plans/completed/YYMMDD.NNNN.slug.md
```

### Agent responsibilities

| Agent | Owns | Output |
|-------|------|--------|
| `flutter-architect` | Planning, decomposition, trade-offs | New plan file in `plans/` |
| `flutter-engineer` | Implementation, tests for new code | Code + tests in the repo |
| `flutter-reviewer` (×3, parallel) | Lens-specific verdicts, priority-ranked findings, patch sketches | Three independent review reports |
| `flutter-testdoctor` | Triage of failing tests, minimal patches | Code/test fixes, re-run of `flutter test` |

The orchestrating agent (the main Claude session driving the pipeline) owns
synthesis: merging the three reports, resolving conflicting verdicts, deciding
which findings to act on, and moving the plan to `completed/` once everyone
signs off.

Priority scale used by reviewers: **P0 / P1 / P2 / P3**.

### Rules

- **No skipping stages.** Every task starts with the architect and ends with the three-reviewer fan-out.
- **Plan file first.** The architect MUST produce a plan file before any code is written. If a plan already exists for the task, update it rather than creating a new one.
- **Three reviewers, three lenses, one message.** All three `flutter-reviewer` agents are launched in a single tool-call batch (multiple `Agent` blocks in one message) so they run in parallel. Each prompt names the lens explicitly and tells the agent what to SKIP (the other lenses) to avoid duplicated work.
- **No solo reviewer pass on first review.** Even for small changes the full three-lens fan-out is required, because the lenses catch genuinely different classes of issue (Lens A won't see ops/log-volume problems; Lens C won't see test gaps). Skipping lenses is what the orchestrator does AFTER a P0/P1 fix, not BEFORE the first verdict.
- **Lens prompts are self-contained.** Each reviewer's prompt must include: (1) the lens name, (2) what to focus on, (3) what to SKIP (so it doesn't restate other lenses), (4) the file list, (5) the deliverable shape (P0 / P1 / P2 / P3 with `file:line` + patch sketch), (6) the word cap (typically 600 words).
- **Re-review after fixes is single-pass.** Once an engineer addresses P0/P1 findings, the orchestrator runs ONE reviewer pass scoped to the changed lines, not the full fan-out. Re-running all three each iteration is expensive and rediscovers nothing.
- **Conflict resolution is explicit.** When reviewers disagree (one says P0, another says trade-off), the orchestrator chooses, names the rejected suggestion, and explains the reasoning to the user before moving on. The user has final say.
- **Orchestrator gates completion.** The plan moves to `plans/completed/` only after every reviewer's P0 and P1 findings are addressed (either fixed, or explicitly accepted with rationale). The rename uses the standard `YYMMDD.NNNN.slug.md` format.
- **`flutter analyze` and `flutter test` must pass** before review begins. If either fails, hand the logs to `flutter-testdoctor` first — reviewers should not waste time on a red tree.
- **Testdoctor is scoped.** It patches tests or the minimal production code needed to make the failure go away. It does not redesign or refactor.
