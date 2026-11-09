---
name: scala-conventions
description: Scala 2.13 / ZIO 2 code style conventions - expression-oriented bodies, match over if chains, Option pipelines, lambda and for-comprehension form, named and one-per-line arguments for constructors and for calls with 3 or more arguments, no logic inside argument lists, no default field values, no Boolean flag parameters, reuse of project combinators, dead-code hygiene. Load before writing or reviewing any Scala code. Not for logic or language-agnostic rules; those live in common-contracts.
paths:
  - "**/*.scala"
  - "**/build.sbt"
---

# Scala conventions

Project `CLAUDE.md`/`AGENTS.md` overrides anything here. In a project that runs scalafmt, scalafmt owns layout; with config-style arguments kept (the scalafmt default), it leaves the one-argument-per-line form below intact, and the other rules cover what the formatter does not change.

## Expressions

- Write a method body as one expression. Inline a `val` used once that only names an intermediate value; do not bind a result just to return it. Exception: the `val` that lifts an `if`/`match` out of an argument list (see Calls and constructors).
- When a method branches on one input's value, normalize it once and `match` on it instead of an `if`/`else` chain of `trim`/`equalsIgnoreCase` comparisons. Example:
  ```scala
  def label: String = status.trim.toLowerCase match {
    case "" | "unknown" => fallbackLabel
    case _              => status
  }
  ```
- Clean a value inside the `Option` pipeline that produces it (`.map(_.trim)`, `.filter(_.nonEmpty)`, `.orElse(...)`); do not test the result afterwards with `if` to pick a fallback.
- Use eta-reduction: `.flatMap(messageOf)`, not `.flatMap(x => messageOf(x))`.
- Write a single-expression lambda with parentheses: `.catchAll(e => ...)`; use braces only for a multi-statement lambda.
- Sequence two or more ZIO effects in a for-comprehension, not a `flatMap(...).map(...)` chain; `Option` clean-up stays a pipeline.
- Match on the type (`case r: Retry => r.attempts`), not on a positional extractor full of `_` (`case Retry(_, _, n, _) => n`).
- Write `Nil`/`None` where the expected type is already known (a declared return type, parameter or field), not `List.empty[(String, String)]`.
- Call a case class without `new`.

## Calls and constructors

- Extract `if`/`else` and `match` expressions from argument lists without changing evaluation order, frequency, or scope. Use a local `val` for a strict argument when moving it preserves evaluation order; use a local `def` called at the original argument position for a by-name argument. Keep callback-dependent computations inside the callback. Keep any comment on the extracted definition. Example:
  ```scala
  // a retry needs the full record, not the summary
  val fields = mode match {
    case Mode.retry => Fields.all
    case _          => Fields.summary
  }

  Request(
    client = client,
    fields = fields
  )
  ```
- Use named arguments, one per line, in tests too: on every constructor and factory call with more than one argument (error types, case classes, `Impl` factories), and on every other call to a Scala-defined method with 3 or more arguments in one argument list. Exempt: calls to Java-defined constructors and methods, whose parameter names are not reliably available to Scala, and arguments to a repeated (`T*`) parameter (`List(a, b)`, `ZLayer.make[R](a, b, c)`), which cannot be named. Example:
  ```scala
  saveMapping(
    orgId = orgId,
    ownerId = ownerId,
    source = source,
    targetId = targetId
  )
  ```
- When the project defines an extension that fails a ZIO with a domain error, raise errors through it instead of `ZIO.fail(...)`, and chain a guard on the same expression (`.unless(cond)`), not around it in an `if`.
- Use the project's existing ZIO/Option combinators instead of rebuilding them (for example, a flat-traverse helper instead of `ZIO.foreach(xs)(f).map(_.flatten)`); search the project's utils before writing a helper.

## Declarations

- Do not give case class fields default values; pass every field at each call site. A field that always holds one constant becomes a `val` in the class body.
- Write two methods instead of one method with a `Boolean` flag parameter (`enable` / `disable`, not `setStatus(enabled: Boolean)`).
- Pass a whole config or model object, not a hand-picked subset of its fields; group parameters that always travel together into one case class.
- Keep the private helpers of an `Impl` class inside that class, not in its companion object.
- For value naming, read and apply R13 in `common-contracts` (`references/go-engineering.md`); this section applies to Scala despite the contract's Go scope.

## Duplication and hygiene

- When the same lookup fails with the same domain error in several places, extract one helper and call it everywhere; that is one decision in several places, so it is not the trivial helper R9 in `common-contracts` (`references/go-engineering.md`; the rule is language-agnostic) bans. Other duplication follows `knowledge:software-design` (Duplication vs abstraction).
- Remove the imports, methods and commented-out code a change leaves unused.
- End every `.scala` file with a newline.
