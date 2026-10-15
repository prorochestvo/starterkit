---
name: postgres-performance
description: PostgreSQL performance doctrine - EXPLAIN analysis, index selection (btree/GIN/GiST/BRIN, partial, covering), connection pooling, autovacuum and bloat, configuration essentials, and lock diagnostics. Load when queries are slow, designing indexes, or operating Postgres under load.
---

# PostgreSQL performance

Distilled from *PostgreSQL High Performance Cookbook* and current Postgres practice. Rule zero: **measure on realistic data** — the planner behaves differently at 1K rows vs 10M.

## Reading queries

- `EXPLAIN (ANALYZE, BUFFERS)` is the tool; run on production-sized data. Red flags: Seq Scan on a large table with a selective filter; estimated rows off from actual by orders of magnitude (stale stats → `ANALYZE`, or correlated columns → `CREATE STATISTICS`); Sort/Hash spilling to disk (`work_mem`); nested loop over a huge outer set.
- `pg_stat_statements` is mandatory in every deployment: find the top total-time queries — the worst offender is usually a mediocre query executed 10K/min, not the slow report.
- `auto_explain` with a threshold catches the plans you can't reproduce.

## Indexing

- **B-tree** (default): equality/range, leftmost-prefix rule for composite indexes — `(a, b)` serves `WHERE a = ?` and `WHERE a = ? AND b = ?`, not `WHERE b = ?` alone. Column order: equality columns first, then range.
- **Partial indexes** for hot subsets: `CREATE INDEX ... WHERE status = 'pending'` — small, cheap to maintain, exactly what the queue-poll query needs.
- **Covering** (`INCLUDE`) to enable index-only scans on hot reads; requires vacuum keeping the visibility map current.
- **GIN** for `jsonb` containment, arrays, full-text; **GiST** for ranges/geometry/exclusion constraints; **BRIN** for huge append-only tables ordered by the indexed column (timestamps) — kilobytes instead of gigabytes.
- Expression indexes must match the query's expression exactly (`lower(email)`).
- Every index taxes every write and vacuum: review `pg_stat_user_indexes.idx_scan` and drop unused ones. Don't index FK columns blindly — index the ones your joins and cascades actually traverse (usually yes, but verify).
- `CREATE INDEX CONCURRENTLY` in production, always; it can fail and leave an INVALID index — check and re-run.

## Connections

- Postgres connections are processes: hundreds of idle connections poison memory and scheduling. Service-side pools sized deliberately (see `stack-go:mistakes` for `database/sql` settings); PgBouncer (transaction mode) in front when many services share one cluster.
- Transaction-mode pooling breaks session state (prepared statements, `SET`, advisory locks) — know what your driver does.
- Watch `pg_stat_activity` for `idle in transaction` — those hold locks and block vacuum; kill them with `idle_in_transaction_session_timeout`.

## Vacuum & bloat

- MVCC means UPDATE/DELETE leave dead tuples; autovacuum reclaims them. Never disable it — tune it.
- High-churn tables (queues, counters): lower `autovacuum_vacuum_scale_factor` (e.g. 0.01) per table so vacuum runs frequently and cheaply.
- Bloat symptoms: table/index size grows while row count doesn't; index-only scans degrade. Monitor with pgstattuple; fix bloat with `pg_repack` (online), not plain `VACUUM FULL` (exclusive lock).
- Long-running transactions (and abandoned replication slots) pin the xmin horizon and block all vacuuming cluster-wide — alert on both.
- HOT updates: updates that don't touch indexed columns avoid index churn — another reason not to over-index.

## Configuration essentials

- `shared_buffers` ~25% RAM; `effective_cache_size` ~70% (planner hint only); `work_mem` per sort/hash node per query — size for concurrency, not generosity.
- `random_page_cost` ≈ 1.1 on SSD/NVMe (default 4 assumes spinning disks and scares the planner off index scans).
- WAL: `max_wal_size` large enough that checkpoints are time-driven (`checkpoint_timeout`), not size-driven; `synchronous_commit = off` only for data you can afford to lose milliseconds of.
- Log slow queries: `log_min_duration_statement` (e.g. 200ms) + `log_lock_waits = on`.

## Locks & hot rows

- Writers don't block readers (MVCC), but writers serialize on the same row: single-row counters and "grab the next job" patterns collapse under concurrency.
- Queue pattern: `SELECT ... FOR UPDATE SKIP LOCKED LIMIT n` — workers take disjoint rows without blocking each other.
- Lock queues cascade: an `ALTER TABLE` waiting behind a long SELECT blocks *everything* after it. Take DDL with `lock_timeout` set (fail fast, retry) during low traffic.
- Diagnose with `pg_locks` joined to `pg_stat_activity`; alert on lock waits, not just CPU.

## Checklist

- [ ] `pg_stat_statements` enabled; top queries reviewed, not guessed.
- [ ] Every new query on a large table has an `EXPLAIN (ANALYZE, BUFFERS)` from realistic data in the PR/plan.
- [ ] Indexes justified by a query, created `CONCURRENTLY`, unused ones dropped.
- [ ] Pool sizes explicit at both app and infra level; `idle in transaction` bounded.
- [ ] Autovacuum tuned per hot table; xmin-horizon (long transactions, stale slots) alerting exists.
- [ ] DDL migrations state their lock level and run with `lock_timeout`.
