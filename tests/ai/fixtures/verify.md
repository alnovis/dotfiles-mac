- **`gbranch.fish:8` — the help text no longer lists the bases** — [CONFIRMED 8/10]
  why: The added line names them.

- **`gbranch.fish:40` — the candidate loop skips release** — [REFUTED 7/10]
  why: The loop reads `$GBRANCH_BASES`, which includes release.

- **`gbranch.fish:115` — `string split \t` breaks on tabs in branch names** — [REFUTED 9/10] ·
  why: Git refuses branch names with tabs.

Verify: 1 confirmed, 1 refuted, 0 uncertain
