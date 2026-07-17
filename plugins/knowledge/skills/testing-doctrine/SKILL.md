---
name: testing-doctrine
description: Testing doctrine - what makes a good test (the four pillars), observable behavior vs implementation details, mock discipline (managed vs unmanaged dependencies), test pyramid shape, and test smells. Load when designing test suites, deciding what and how to mock, or reviewing test quality.
---

# Testing doctrine

Distilled from *Unit Testing Principles, Practices, and Patterns* (Vladimir Khorikov). Structure conventions (naming, subtests) live in the stack skill; this is about **what to test and how not to lie to yourself**.

## The four pillars (grade every test against them)

1. **Protection against regressions** — does it catch real bugs? Tests of trivial code (getters, mappers with no logic) score zero here and are ballast.
2. **Resistance to refactoring** — does it survive a refactor that preserves behavior? A test coupled to implementation details fails on rename/restructure and trains people to ignore red. *This pillar is non-negotiable; the others trade off against each other.*
3. **Fast feedback** — slow suites stop being run.
4. **Maintainability** — small, readable, no hidden machinery.

False positives (test red, behavior fine) erode trust faster than missed bugs. If a refactor broke fifty tests but zero behavior, the tests were wrong.

## Test observable behavior, not implementation

- Assert on **outcomes visible to the caller**: return values, state changes observable through the public API, messages sent to external systems. Never assert "method X called internal method Y".
- The unit of "unit test" is a **unit of behavior**, not a class. A test may exercise several classes together if they form one behavior; that's still a unit test when it's fast and isolated from out-of-process dependencies.
- If a test needs to know private structure to pass, the test (or the API) is wrong.

## Mock discipline (the core rule)

Split dependencies into:

- **Managed** (owned by the app, invisible to the outside): your database, your filesystem state. **Do not mock** — use the real thing (or in-memory/testcontainer equivalent). Mocking your own DB verifies conversation, not behavior, and lets schema/SQL bugs through. Communication with managed dependencies is an implementation detail.
- **Unmanaged** (observable by external parties, contract-bound): third-party APIs, payment gateways, message buses consumed by others, sent emails. **Mock/fake these** — the communication pattern itself *is* the observable behavior, and you can't hit them for real in tests.

Corollaries:
- Mock only types you own at the boundary (wrap third-party clients in your own interface; mock the wrapper).
- Verify the *fact and payload* of the outgoing interaction (`Publish` called with correct event), not the choreography of internal calls.
- Overspecified mocks (`.Times(3)`, ordering asserts without a contract reason) are refactoring landmines.

## Architecture for testability

- **Humble object pattern**: split "hard to test" (I/O, UI, time, randomness) from "worth testing" (decisions). Business logic in pure functions/domain objects (test heavily, no mocks needed); thin orchestration around it (integration tests); glue too dumb to break (don't test).
- Inject clocks and randomness; a `time.Sleep` in a test is a design smell (see stack skills).
- Output-based (pure function) tests > state-based > communication-based (mocks). Push code toward the left of that ranking.

## Suite shape

- Bulk: fast in-process tests of domain logic and algorithms.
- A meaningful band of **integration tests through real managed dependencies** (real Postgres in a container beats a mocked repository) covering each external touchpoint's happy path + key failure.
- A handful of end-to-end smoke tests. An inverted pyramid (all E2E) is slow and flaky; an all-mocks suite is fast and worthless.
- Coverage is a negative indicator only: low coverage proves gaps; high coverage proves nothing. Never make a number the goal.

## Test smells (review checklist)

- [ ] Test breaks when internals are refactored without behavior change → coupled to implementation.
- [ ] Mocked repository/DB owned by the app → replace with real dependency.
- [ ] Assertion-free test, or asserting only "no error" on a rich result.
- [ ] Logic in tests (if/for/computation of expected values) — expected values are literals; a bug in test logic hides a bug in code.
- [ ] Shared mutable fixtures coupling tests to execution order.
- [ ] Sleep-based synchronization; time-dependent expectations without an injected clock.
- [ ] Trivial tests padding coverage (testing the language, the framework, or a mapper with no branches).
