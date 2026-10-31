## Summary
gbranch now picks the nearest base branch instead of always preferring develop.

## Critical issues
(none)

## Important issues
1. fish/.config/fish/functions/gbranch.fish:24 — `git merge-base` is called once per candidate
   branch; on a repo with many remote branches this makes `gbranch` slow.

## Nits
2. fish/.config/fish/functions/gbranch.fish:31 — the variable name `best` does not say what is
   being compared; `nearest_base` would read better.
