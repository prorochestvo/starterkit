---
name: ddd-tactical
description: Tactical domain-driven design - value objects, entities, aggregates and invariants, domain events, repositories, and typed domain modeling (making illegal states unrepresentable). Load when modeling domain objects, designing aggregates, enforcing invariants, or structuring a domain layer.
---

# Tactical DDD

Distilled from *Implementing Domain-Driven Design* (Vaughn Vernon), *Go With The Domain* (Three Dots Labs), and *Domain Modeling Made Functional* (Scott Wlaschin). Tactical patterns are for **core** subdomains — a supporting CRUD screen does not need aggregates (see `knowledge:ddd-strategic`).

## Value objects (default building block)

- Identity-less, immutable, defined by their attributes: `Money`, `Email`, `DateRange`, `Coordinates`. Two value objects with equal attributes are equal.
- **Validate in the constructor; exist only valid.** `NewEmail("not-an-email")` returns an error; an `Email` that exists is correct by construction. This removes scattered re-validation and the "is this string checked yet?" class of bug.
- Model as much as possible as value objects — primitives (`string userID`, `float64 amount`) invite mixing up arguments and skipping validation ("primitive obsession").
- Operations return new values (`price.Add(tax)`), never mutate.

## Make illegal states unrepresentable

- Prefer types that cannot express invalid combinations over runtime checks: separate `UnverifiedEmail` vs `VerifiedEmail` types instead of a `verified bool`; a `PaidOrder` type instead of `if order.Status == "paid"` scattered around.
- Model state machines as explicit states with legal transitions as methods (`draft.Submit() (Submitted, error)`), not as a status string plus discipline.
- Optional means optional in the type (`*T`, `Option`), not "empty string means missing".
- In Go: unexported struct fields + validating constructor + methods = the enforcement mechanism. If a struct's zero value is invalid, its fields must be unexported and construction forced through `New*`.

## Entities

- Have identity that persists across attribute changes (`User`, `Order`). Equality by ID, not attributes.
- Keep behavior on the entity: `order.AddItem(item)` enforcing its own rules — not an anemic struct mutated by a "manager" service. An anemic model with all logic in services is procedural code wearing DDD clothes.

## Aggregates (consistency boundaries)

- An aggregate is a cluster of entities/values changed **as one unit in one transaction**, guarded by a root. External code references the root only, by ID — never holds pointers into the inside.
- **The aggregate is the invariant boundary**: a rule that must hold *always* ("order total = sum of lines") lives inside one aggregate. A rule that may lag ("customer's order count") spans aggregates via eventual consistency.
- **Keep aggregates small.** Default to one entity per aggregate; grow only when a true always-consistent invariant demands it. Huge aggregates serialize all writes through one lock and kill throughput.
- One transaction modifies one aggregate. Cross-aggregate changes = domain events + eventual consistency, or a saga for multi-step flows.
- All mutation goes through root methods that enforce invariants and either fully succeed or leave state unchanged.

## Domain events

- Record facts that happened, past tense, in domain language: `OrderPlaced`, `PaymentFailed`. Raised by aggregates during mutation, published after the owning transaction commits.
- Use them to decouple contexts (integration events) and to trigger side effects (email, projections) without stuffing those into the aggregate's transaction.
- **Reliable publishing needs an outbox**: write the event to an outbox table in the same transaction as the state change; a relay publishes from the outbox. Publishing to a broker inside the transaction (or after, unguarded) drops or ghosts events (see `knowledge:data-systems`).

## Repositories & services

- A repository provides collection-like access to **aggregate roots only** (one repository per aggregate, not per table). Its interface is defined in/next to the domain (consumer side); implementation lives in the infrastructure layer.
- Repositories return whole aggregates ready to enforce invariants — not row fragments the service reassembles.
- **Domain service**: logic spanning multiple aggregates that belongs to no single one (`TransferService` between two `Account`s). Stateless, domain language, no I/O orchestration.
- **Application service / use case**: orchestrates — load aggregate, call behavior, persist, publish events. Thin; contains no business rules itself. This is the transaction boundary.
- Keep the domain layer dependency-free: it imports nothing from infrastructure; infrastructure implements domain-defined interfaces (ports & adapters).

## Checklist

- [ ] No primitive obsession on domain concepts crossing boundaries (IDs, money, emails are types).
- [ ] Every domain type is valid by construction; zero-value-invalid structs are unexported-field + constructor.
- [ ] Aggregates small; every invariant assignable to exactly one aggregate; one aggregate per transaction.
- [ ] No external references into aggregate internals (by-ID references between aggregates).
- [ ] Events published via outbox, not inside/around the transaction unguarded.
- [ ] Business rules live in domain objects, not in application services (no anemic model).
