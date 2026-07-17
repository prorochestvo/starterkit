---
name: mongodb-modeling
description: MongoDB data modeling and operations - embedding vs referencing decisions, schema patterns, index rules (ESR), write concerns and durability, aggregation discipline, and antipatterns (unbounded arrays, hot documents). Load when designing MongoDB schemas or reviewing MongoDB usage.
---

# MongoDB modeling & operations

Distilled from *MongoDB: The Definitive Guide* (Chodorow) and current MongoDB practice. The prime directive: **data that is accessed together is stored together** — model around query patterns, not around normalized entities.

## Embedding vs referencing

Embed when:
- The child is accessed with the parent in the same operations (order + its lines).
- The child has no meaning outside the parent.
- The set is **bounded and small** (tens, not thousands).
- You need atomic updates of parent+children (single-document updates are atomic).

Reference when:
- The set is unbounded or grows monotonically (events, comments, logs).
- The child is queried independently or shared by many parents.
- The parent is hot and the child churns (separating cuts write amplification).

Hybrid (extended reference): embed the few fields you always need with the reference (`{userId, userName}`), accept the update-fanout when the copied field changes — copy only slow-changing fields.

## Antipatterns

- **Unbounded arrays** — an array that grows forever (all events on a device doc): documents crawl toward the 16MB cap, every append rewrites more, indexes on the array bloat. Fix: one document per item, or the **bucket pattern** (one doc per device per hour/day with a capped array).
- **Treating MongoDB as relational** — normalizing everything into id-only docs and "joining" with `$lookup` per request. `$lookup` is for occasional analytics, not the hot path; if every read needs three lookups, the model is wrong (or the workload is relational — use Postgres).
- **Hot single document** — a global counter/config doc every request writes: document-level concurrency serializes on it. Shard the counter (N docs summed on read) or move it out.
- **Massive negation queries** — `$ne`/`$nin`/`$not` can't use indexes selectively.
- **Schemaless as no-schema** — "flexible schema" means the *application* owns the schema. Enforce it: schema validation (`$jsonSchema`) on collections, versioned migration strategy (schema-version field + lazy migration), typed structs in code.

## Indexing

- **ESR rule** for compound indexes: **E**quality fields first, then **S**ort fields, then **R**ange fields. `find({status: "A", ts: {$gt: x}}).sort({created: -1})` wants `{status: 1, created: -1, ts: 1}`.
- The prefix rule applies as in B-trees: `{a: 1, b: 1}` serves queries on `a`, not on `b` alone.
- Covered queries: all projected fields in the index → no document fetch.
- Every index costs writes and RAM (indexes must fit in working set). Review with `$indexStats`, drop unused.
- `explain("executionStats")`: `totalDocsExamined` should be close to `nReturned`; a big ratio means a scan or a bad index. `COLLSCAN` on a large collection in the hot path is a finding.
- Multikey (array) indexes: one entry per element — an index on a 1000-element array field writes 1000 entries per document.

## Durability & consistency

- Write concern is a per-operation choice: `w: "majority"` for anything you can't lose; `w: 1` accepts rollback on failover. Read concern/preference likewise: secondary reads are **stale reads** — use only where staleness is explicitly fine.
- Multi-document transactions exist but cost dearly; needing them everywhere is the "workload is relational" smell. Prefer models where the invariant lives inside one document (see embedding).
- Idempotent writes (upserts with deterministic `_id`) survive retries; `retryWrites=true` covers single ops, not read-modify-write races — use `findOneAndUpdate` with operators (`$inc`, `$push`) instead of read-then-set.

## Aggregation discipline

- `$match` and `$project` as early as possible (use indexes, shrink the stream); `$lookup`/`$unwind` late and rarely.
- Pipelines that reshape entire collections on the hot path are ETL in disguise — precompute (materialized view pattern: incremental `$merge`) instead.
- `allowDiskUse` is a confession that the pipeline outgrew RAM — fine for batch, a bug in request paths.

## Checklist

- [ ] Every collection's design justified by its top queries (written down), not by entity purity.
- [ ] No unbounded arrays; growth paths named for every embedded set.
- [ ] Compound indexes follow ESR; `explain` ratios checked on new hot queries.
- [ ] Write/read concerns explicit per operation class; stale-read tolerance documented.
- [ ] Schema validation active; schema version field present from day one.
