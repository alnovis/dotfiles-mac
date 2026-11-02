**[F1] lost update between two writers** (`a.fish:3`)
- [CONFIRMED 7/10]
  why: run 2 agrees, a cron thread rewrites the field.

- [F2] the list is reversed — REFUTED 8/10
  why: run 2: the head is the oldest element.
- [F3] missing timeout — [REFUTED 7/10]
  why: run 2 found the timeout in the client config.
- an unnumbered finding — [CONFIRMED 9/10]
  why: no number, cannot be matched.
