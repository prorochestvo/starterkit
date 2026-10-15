---
name: software-design
description: Software design doctrine - complexity as the enemy, deep vs shallow modules, information hiding, when to duplicate vs abstract, define-errors-out-of-existence, strategic vs tactical programming, and comment discipline. Load when designing module boundaries, APIs, abstractions, or judging whether an abstraction pays its rent.
---

# Software design

Distilled from *A Philosophy of Software Design* (John Ousterhout). The single enemy is **complexity**: anything that makes a system hard to understand or modify. It arrives incrementally — by accepting "just this once" dependencies and obscurity — and compounds.

Symptoms of complexity: **change amplification** (one logical change touches many places), **cognitive load** (how much a developer must hold in their head), and **unknown unknowns** (it's not obvious what must change or where the information you need lives). The last is the worst.

## Deep vs shallow modules

- A module's value = functionality it hides ÷ interface it exposes. **Deep**: small interface, serious implementation behind it (a file API hiding caching, buffering, permissions). **Shallow**: a wide interface over nearly nothing (a wrapper that renames three methods).
- Shallow modules are complexity with extra steps: the interface costs learning but hides nothing. A pass-through method (same signature in, same call out) is a red flag — one abstraction split across two homes.
- **Classitis / layeritis**: decomposing until every piece is tiny doesn't reduce complexity, it relocates it into the seams. Interfaces are the cost; count them.
- The best modules make the common case trivial: **somewhat general-purpose** interfaces ("do X") outlive special-purpose ones ("do X for the settings screen") — but generality must be driven by known needs, not speculation.

## Information hiding & leakage

- Each module hides design decisions (formats, algorithms, storage) so they can change without touching callers.
- **Leakage** is when a decision is visible in multiple modules — two files that must change together (both know the serialization format) leak even if neither imports the other. Fix by giving the knowledge one home.
- Temporal decomposition (structuring code by execution order — `readFile`, `processFile`, `writeFile` each knowing the format) is a classic leak; structure by knowledge instead.

## Duplication vs abstraction

- Duplication is a smell **only when it duplicates a decision**. Coincidental similarity — two snippets that look alike today but serve different masters — must stay duplicated and free to diverge; unifying them couples unrelated evolution.
- Extract when the abstraction has a **name in the domain of the problem** and hides a real decision; never extract just because lines match. A helper that needs six parameters and a boolean mode flag to serve both callers is the tell that the similarity was coincidental.
- An abstraction must be **deeper than the code it replaces** — if calling it requires understanding its internals (or its name is `doProcess`), it subtracts value.

## Errors & edge cases

- **Define errors out of existence**: redesign APIs so the error case can't occur — deleting a missing file is a no-op success; `substring` clamps out-of-range instead of throwing; unset config gets a sane default. Every exception path a caller must handle is interface complexity.
- Where errors are real, handle them once at a level that can act, not at every level (see stack error contracts).
- **Pull complexity downward**: it is better for the module implementer to suffer than every caller — no configuration parameters that outsource decisions the module could make itself.

## Strategic vs tactical programming

- Tactical: fastest path to working now; each shortcut leaves a little complexity behind; velocity decays toward zero. Tactical tornadoes ship features and leave craters.
- Strategic: working code is not the goal — a great design that also works is. Invest continuously (~10–20% time) in design improvements as you touch code.
- When a change fights the current design, consider redesigning-then-changing over patching around — but scope it as its own deliberate task (one plan per concern), not a drive-by.

## Comments & names (design tools, not decoration)

- Comments capture what code cannot: **why**, invariants, units, ownership/lifetime, out-of-bounds behavior. A comment repeating the code is noise; the valuable comment is the one you wish you'd had while debugging.
- Interface comments describe what callers need (contract); implementation comments explain non-obvious how/why. If a module needs paragraphs to explain its interface, the interface is too complex — comments are a design feedback tool.
- Names are tiny abstractions: precise, consistent (one word per concept codebase-wide). If a good short name won't come, the entity's design is probably blurry.

## Design review checklist

- [ ] New modules deep? (interface small relative to what it hides; no pass-throughs)
- [ ] Any decision with two homes? (format/protocol/layout known by >1 module)
- [ ] Abstractions named by domain meaning, extracted over real decisions, not line similarity.
- [ ] Error cases designed away where possible; remaining ones handled at one level.
- [ ] Complexity pulled down into implementations, not pushed up into interfaces/config.
- [ ] Names and comments record intent and invariants, not restatements.
