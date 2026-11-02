I checked every finding.

- [F1] `a.fish:3` — lost update between two writers — [CONFIRMED 8/10]
  why: run 1 found the second writer in the scheduler.
- [F2] `b.fish:7` — the list is reversed — [REFUTED 9/10]
  why: run 1: `:+` appends at the tail.
- [F3] `c.fish:9` — missing timeout — [CONFIRMED 6/10]
  why: run 1 saw no timeout.
- [F4] `d.fish:1` — only this run judged it — [CONFIRMED 7/10]
  why: run 1 alone.

Verify: 4 confirmed, 1 refuted, 0 uncertain
