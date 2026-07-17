---
name: sql-antipatterns
description: SQL schema and query antipattern catalog - comma-separated lists, EAV, polymorphic FKs, multicolumn sprawl, floating money, enum-in-check, index misuse, NULL traps, GROUP BY violations, N+1, and injection. Load when designing schemas, writing migrations, or reviewing SQL.
paths:
  - "**/*.sql"
  - "**/migrations/**"
---

# SQL antipatterns (review catalog)

Distilled from *SQL Antipatterns* (Bill Karwin). Each entry: the smell → why it breaks → the fix. Legitimate uses exist for some — the crime is using the antipattern by default.

## Schema design

- **Comma-separated lists in a column** (`tags = 'a,b,c'`) → can't index, can't FK, can't join, LIKE-scans everywhere. Fix: intersection (junction) table. Legit exception: opaque display-only data, or a deliberately denormalized cache with the source of truth elsewhere.
- **Multicolumn sprawl** (`phone1, phone2, phone3`) → arbitrary limit, queries OR over N columns. Fix: dependent table, one row per value.
- **Entity-Attribute-Value** (`entity_id, attr_name, attr_value`) → no types, no NOT NULL, no FK, monstrous pivot queries. Fix: model known attributes as columns; subtype tables (class-table or single-table inheritance) for variants; a `jsonb` column for genuinely dynamic attributes — with the discipline that indexed/queried fields get promoted to real columns.
- **Polymorphic association** (`commentable_type + commentable_id`) → no real FK, integrity by convention. Fix: separate FK columns (nullable, CHECK exactly-one-set) or junction tables per parent type.
- **FK-less "for flexibility"** → orphans accumulate silently; app-side checks race. Fix: real constraints — they are executable documentation. Cascades chosen deliberately (`ON DELETE RESTRICT` default; `CASCADE` only where child data is truly ownerless without the parent).
- **Enum in a CHECK / DB enum for volatile sets** → adding a value = migration (or `ALTER TYPE`); can't attach metadata. Fix: reference (lookup) table with FK. DB enums acceptable for genuinely closed sets (days of week).
- **Floating-point money** (`FLOAT`) → rounding errors compound. Fix: `NUMERIC(p,s)` or integer minor units.
- **Images/blobs in rows by default** → backup bloat, memory pressure. Files in object storage, path + checksum in the DB — unless transactional integrity of the bytes is the actual requirement.
- **Pseudokey neurosis** — obsessing over gap-free IDs; gaps are normal (rollbacks, concurrency). Never reuse or renumber keys.
- **ID everywhere without natural keys considered** — surrogate PKs are a fine default, but add UNIQUE constraints on the real natural key (email, code) or duplicates will breed.

## Query traps

- **Fear of NULL** — `x <> 'value'` silently drops NULL rows; `NULL = NULL` is not true. Use `IS [NOT] DISTINCT FROM`, `COALESCE`, explicit `IS NULL` branches. Don't invent magic values (-1, '1900-01-01') to avoid NULL — that's worse.
- **Ambiguous GROUP BY** — selecting non-aggregated columns not in GROUP BY (MySQL's loose mode picks arbitrary values). Every selected column: grouped, aggregated, or functionally dependent on the group key. "Latest row per group" = window function (`ROW_NUMBER() OVER (PARTITION BY ... ORDER BY ...)`) or lateral join.
- **`ORDER BY RAND()` / `random()`** — sorts the whole table per query. Fix: random offset, or `TABLESAMPLE`.
- **Poor man's search engine** — `LIKE '%word%'` unindexable at scale. Fix: full-text search (`tsvector` + GIN) or trigram indexes (`pg_trgm`); external engine when relevance ranking matters.
- **Implicit columns** — `SELECT *` in production code and `INSERT` without column lists break on schema change and fetch dead weight. Name the columns.
- **N+1 queries** — a loop issuing one query per row. Fix: JOIN, `WHERE id = ANY(...)`, or batched IN. Spot it in ORMs by logging query counts per request.
- **Spaghetti query** — one query trying to answer five questions via forests of JOINs and DISTINCT patches (unexpected row multiplication from many-to-many joins is the tell). Split into separate queries or CTEs; DISTINCT slapped on to "fix" duplicates is a red flag.

## Application-side

- **SQL injection** — string-built SQL. Parameterized queries always; identifiers (table/column names) can't be parameters — whitelist them. This is non-negotiable, including in "internal" tools.
- **Readable passwords** — plaintext/reversible or fast-hash (MD5/SHA-x) passwords. Argon2id/bcrypt/scrypt with per-user salt; reset flows, never "email me my password".
- **Diplomatic immunity** — treating SQL as beneath code review, version control, and tests. Migrations are code: reviewed, versioned, tested, rollback-considered.
- **Magic beans / ORM worship** — letting the ORM design the schema and queries unexamined. The ORM is a mapper; schema and hot queries are designed and reviewed as SQL (`EXPLAIN` on anything non-trivial — see `knowledge:postgres-performance`).

## Migration discipline

- Additive first: new column (nullable/defaulted) → backfill in batches → tighten constraint → drop old. Never rewrite a large hot table in one transaction.
- Every migration states its lock impact (does this take ACCESS EXCLUSIVE? for how long?) and is idempotent or clearly single-shot.
- Destructive migrations (drops, irreversible transforms) are flagged as such and separated from deploys that can roll back.
