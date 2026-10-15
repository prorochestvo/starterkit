---
name: data-systems
description: Data systems fundamentals - transactions and isolation levels, replication and replication lag, exactly-once myths and idempotent consumers, outbox pattern, event logs vs queues, partitioning, and storage engine trade-offs. Load when choosing storage/messaging, designing cross-service data flows, or debugging consistency issues.
---

# Data systems fundamentals

Distilled from *Designing Data-Intensive Applications* (Martin Kleppmann). The recurring theme: **the guarantees you assume are stronger than the guarantees you configured.**

## Transactions & isolation

- Default isolation is not serializable: Postgres/MySQL default to Read Committed / Repeatable Read. Know what your level does NOT prevent:
  - **Lost update**: two read-modify-writes interleave → one vanishes. Fix: atomic ops (`UPDATE ... SET x = x + 1`), `SELECT FOR UPDATE`, or optimistic version checks.
  - **Write skew**: two transactions each check a condition, then write different rows, jointly violating the invariant (two doctors both go off-call). Fix: serializable isolation, or materialize the conflict into a lockable row/constraint.
  - **Phantoms**: a predicate ("no booking overlaps") isn't lockable by rows that don't exist yet — needs serializable or an exclusion constraint.
- Rule: state every multi-step invariant explicitly, then name the mechanism enforcing it (constraint > atomic op > lock > serializable). "The code checks first" is not a mechanism under concurrency.
- Long transactions hold locks and block vacuum-style maintenance — keep transactions short; never do network I/O inside one.

## Replication

- **Replication lag is not an edge case.** Async replicas are always behind (ms to minutes under load). Read-your-own-writes breaks when reads hit replicas: route the writer's subsequent reads to the primary (or token/LSN-based read-after-write).
- Failover of an async primary can **lose acknowledged writes**. If a write must survive failover, it needs synchronous/quorum acknowledgment — and that costs latency. Choose per data class, not globally.
- Monotonic reads: a user bouncing between replicas can see time go backwards; pin sessions if it matters.

## Messaging: the exactly-once myth

- Delivery is **at-least-once** in every practical system (retries after unacked processing). "Exactly-once delivery" marketing means "at-least-once + dedup/transactional processing".
- Therefore every consumer is **idempotent**: dedup by message/idempotency key, upserts instead of inserts, version checks. Design the handler so processing twice is harmless — this is a requirement, not an optimization.
- **Dual-write is a bug factory**: writing to DB *and* publishing to a broker as two separate operations means one will eventually succeed alone (ghost events or missed events). Fix: **transactional outbox** — event written to an outbox table in the same DB transaction; a relay (poller or CDC/Debezium) publishes. See `knowledge:ddd-tactical`.
- **Log (Kafka-style) vs queue (RabbitMQ/SQS-style)**: a log retains ordered history, consumers track offsets, replay is possible, ordering per partition; a queue deletes on ack, offers per-message routing/retry/DLQ ergonomics. Choose by need: replay/fan-out/ordering → log; task distribution with per-task retry → queue.
- Ordering guarantees are per-partition/per-key only — cross-key ordering doesn't exist at scale. Pick partition keys to align with the invariant (all events of one aggregate → same partition).

## Storage engines & derived data

- **B-tree** (Postgres/MySQL): read-optimized, in-place updates. **LSM** (RocksDB/Cassandra/ClickHouse-ish): write-optimized, compaction cost later. High-ingest workloads on B-trees and read-heavy point lookups on LSMs both fight their engine.
- **OLTP vs OLAP**: row stores for transactional point access, column stores for scanning aggregates over millions of rows. Reporting queries on the OLTP primary is how databases die — replicate/ETL to a replica or warehouse.
- **Derived data is rebuildable**: caches, search indexes, materialized views, read models are projections of a source of truth. Every one answers: how is it invalidated/updated, how stale may it be, how do we rebuild from scratch? A cache without an invalidation story is a future incident (see the dogpile note in `knowledge:production-stability`).
- Schema evolution: producers and consumers deploy independently — formats must be backward/forward compatible (additive fields, no repurposing tags/names). Applies to APIs, events, and stored blobs alike.

## Partitioning (sharding)

- Partition by key (hash for even spread, range for range queries); a hot key (celebrity problem) defeats hashing — know your skew.
- Secondary indexes across partitions are scatter/gather; re-partitioning is a project, not a config change. Delay sharding until a single node with replicas genuinely can't — most systems never need it.

## Checklist

- [ ] Every multi-step invariant has a named enforcement mechanism (constraint / atomic op / lock / serializable).
- [ ] Reads after writes: routing accounts for replication lag where it matters.
- [ ] Every consumer idempotent; every DB+broker write pair goes through an outbox.
- [ ] Every cache/read model has invalidation, staleness bound, and rebuild story.
- [ ] Event/API schemas evolve additively; compatibility tested.
- [ ] No analytics scans on the OLTP primary.
