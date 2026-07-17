---
name: ddd-strategic
description: Strategic domain-driven design - subdomain classification (core/supporting/generic), bounded contexts, ubiquitous language, and context mapping. Load when carving a system into modules or services, deciding build-vs-buy, naming domain concepts, or drawing boundaries between teams/components.
---

# Strategic DDD

Distilled from *Domain-Driven Design* (Eric Evans) and *Learning Domain-Driven Design* (Vlad Khononov). Strategic design decides **where the boundaries are and where the effort goes** — before any tactical pattern matters.

## Subdomain classification (decides where effort goes)

Classify every part of the problem space:

- **Core** — what the business competes on; complex, changes often, differentiator. Build in-house, put the best design effort here, expect heavy iteration.
- **Supporting** — necessary but not differentiating; simple ETL/CRUD around the core. Build simply, do not gold-plate; a transaction script is fine.
- **Generic** — solved problems (auth, billing, email, monitoring). Buy or adopt off-the-shelf; writing your own is strategic malpractice.

Applying core-grade engineering (aggregates, event sourcing, deep models) to a supporting subdomain is over-engineering; applying CRUD thinking to the core is under-engineering. **Match the pattern to the subdomain type.**

## Ubiquitous language

- One language per bounded context, shared by code, tests, docs, and conversation with domain experts. `Order` means exactly one thing inside a context.
- The code *is* the language: class/function names use the domain terms, not tech jargon (`SubmitClaim`, not `ProcessData`). If the expert says "policy is bound", the method is `Bind()`.
- Translation happens **only at context boundaries** — inside a context, a term is never overloaded. When two meanings of "Customer" fight, that's two contexts, not one class with modes.
- No language police needed if the model is right; constant translation friction in conversation is a boundary smell.

## Bounded contexts

- A bounded context is the boundary within which a model and its language are consistent. It is a **solution-space** decision (you choose the size); subdomains are problem-space (discovered, not chosen).
- Rules of thumb: a context is owned by exactly one team (one team may own several contexts); one context = one deployable/schema by default; models are never shared across contexts — integrate through explicit contracts.
- Splitting too fine costs integration overhead; too coarse breeds a model that means nothing. When unsure, start coarser — merging contexts later is harder than splitting.
- In a modular monolith the same rules apply with packages/modules instead of services: separate models, explicit interfaces between them, no reaching into another module's tables.

## Context mapping (relationships between contexts)

Name the relationship explicitly; each has different coupling costs:

- **Partnership** — two teams coordinate as equals; requires real communication bandwidth.
- **Shared kernel** — a shared model subset (shared lib/schema); cheap to start, expensive forever: every change is a multi-team negotiation. Keep the kernel minimal or avoid.
- **Customer–supplier** — downstream can negotiate requirements with upstream.
- **Conformist** — downstream swallows the upstream model as-is (typical with external providers or a much stronger team); accept only when translation isn't worth it.
- **Anticorruption layer (ACL)** — downstream translates the upstream model into its own before letting it touch domain code. Default choice when integrating with legacy or third-party APIs: keep the mess at the boundary.
- **Open-host service / published language** — upstream exposes a stable, versioned public contract (REST/gRPC/events) decoupled from its internal model.
- **Separate ways** — no integration; duplicate the small thing instead of coupling to another context for it.

## Boundary heuristics

- Split where the **language** splits (same word, different meaning / different word, same thing).
- Split where **change cadence** splits (parts that change together stay together).
- Split where **consistency requirements** split: things needing transactional consistency belong in one context; eventual consistency is the default between contexts.
- Do not split by technical layer ("validation service", "database service") — that's distribution of a layered cake, not domain boundaries.

## Checklist

- [ ] Each part of the system labeled core / supporting / generic, with effort matched to the label.
- [ ] Every domain term has one meaning within its context; translations live at boundaries (ACL/OHS), not scattered.
- [ ] Every cross-context relationship named (partnership, ACL, conformist, ...), not accidental.
- [ ] No model or database shared silently across contexts.
- [ ] Generic subdomains bought/adopted, not hand-built.
