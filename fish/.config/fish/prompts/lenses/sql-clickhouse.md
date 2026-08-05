ClickHouse lens. OLAP / columnar defects — ClickHouse is NOT Postgres, and carrying over OLTP habits is the bug. Focus on MergeTree design, query cost, and mutation / dedup semantics. SQL may be inline (clickhouse client / JDBC) or in DDL.

HARD GATE: for every finding, cite the query, DDL, or engine file:line and the concrete consequence — a full scan reading every granule, a memory-blowing JOIN/GROUP BY, a heavy mutation, or silently wrong dedup. If the `ORDER BY` / partition / skip-index that makes the query cheap already exists (show it), DROP the finding. "Would be indexed in Postgres" is not a ClickHouse finding.

Where to look first (non-exhaustive — reason beyond this list):
- Query filtering on a column that is NOT a prefix of the table's `ORDER BY` (primary key), with no data-skipping index → reads every granule.
- Point `UPDATE`/`DELETE` via `ALTER TABLE … UPDATE/DELETE` (mutations) on a hot path — they rewrite whole parts, not rows.
- `JOIN` with the large table on the right (the right side is loaded into memory), or a `JOIN` where a dictionary / `IN` subquery was meant.
- `PARTITION BY` too granular (e.g. by day over years) → thousands of parts; or partitioning by a high-cardinality key.
- `ReplacingMergeTree`/`AggregatingMergeTree` read without `FINAL` or a `GROUP BY` rollup → duplicates or partial aggregates served as truth; or `FINAL` on a hot query (expensive).
- `Nullable` columns where a default sentinel would do → extra storage and slower reads.
- `SELECT *` on a wide columnar table when two columns are used — defeats columnar storage.
- High-cardinality `GROUP BY`/`ORDER BY` with no `LIMIT`/`LIMIT BY` → memory blow-up.
- Row-by-row or tiny `INSERT`s instead of batched (or async) inserts → too many parts, merge pressure.
- Wrong engine for the intent (plain `MergeTree` where a `SummingMergeTree` or a materialized view was meant).
