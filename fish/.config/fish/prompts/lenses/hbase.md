HBase lens. Wide-column access-pattern defects (HBase Java client, or Phoenix over it). The bug is almost always the row-key or the scan shape — HBase has no secondary index or joins to rescue a bad access path.

HARD GATE: for every finding, cite the code or schema file:line and the concrete consequence — region hotspotting, a full-table scan, or unbounded fan-out. If the row-key / salting / scan bound that avoids it is present (show it), DROP the finding. Relational advice (add an index, normalize) does not apply to HBase — do not raise it.

Where to look first (non-exhaustive — reason beyond this list):
- Monotonic row-key (timestamp, sequence, incrementing id) as the leading portion → all writes hit one region (hotspot); needs salting / hashing / a reversed key.
- A read pattern forced into a full-table `Scan` because the row-key doesn't lead with the filtered dimension.
- `Scan` with no `startRow`/`stopRow` bound, or missing `setCaching`/`setBatch` → pulls the whole table or triggers RPC storms.
- Client-side filtering after fetching everything, instead of a `PrefixFilter` / key-range scan.
- Too many column families (HBase flushes per family), or unbounded versions / qualifiers per row.
- Missing TTL or version cap → rows grow without bound.
- `Get` in a loop where a batched `Get` / scan would do; a fat row that must be read whole.
- Phoenix: a query whose `WHERE` doesn't hit the primary-key prefix → full scan behind a SQL face.
