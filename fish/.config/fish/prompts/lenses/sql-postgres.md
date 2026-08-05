PostgreSQL lens. Relational / OLTP defects in Postgres queries, schema, and migrations — wrong results, unbounded scans, and locking/transaction hazards. SQL may be inline (JDBC / jOOQ / Slick / Doobie / Spring Data) or in `.sql` migrations.

HARD GATE: for every finding, cite the query or schema file:line and the concrete consequence — a wrong/duplicated result, a sequential scan on a large table, a lock/deadlock, or an unsafe migration. If an index, constraint, or transaction boundary that removes the risk already exists (show it), DROP the finding. A preference on SQL formatting is not a finding.

Where to look first (non-exhaustive — reason beyond this list):
- `UPDATE`/`DELETE` with no `WHERE`, or a `WHERE` that fails to bind a tenant/owner — mass mutation.
- Predicate that can't use an index: leading wildcard `LIKE '%x'`, a function on the column (`WHERE lower(email) = …`), or an implicit cast → seq scan.
- N+1: a query executed per row of a prior result instead of a join / `IN` / batch.
- Missing index for a frequent filter/join/foreign key; or a redundant duplicate index added.
- `SELECT *` feeding a projection that needs two columns; an unbounded result with no `LIMIT` / pagination.
- Transaction hazards: `SELECT … FOR UPDATE` lock ordering that can deadlock, a long transaction holding locks, read-modify-write without a constraint or `ON CONFLICT`.
- `NULL` semantics: `NOT IN (subquery with NULLs)`, `= NULL`, an aggregate over a nullable column that changes the count.
- Migration safety: `ADD COLUMN … NOT NULL DEFAULT` or a new index without `CONCURRENTLY` on a hot table → long lock; a destructive `DROP` / type change with no backfill.
- Wrong types where it bites: float money, `timestamp` without time zone, `serial` vs identity, unbounded `text` used as a key.
