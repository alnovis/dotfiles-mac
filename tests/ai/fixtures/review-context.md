## Summary
gbranch now picks the nearest base branch instead of always preferring develop.

## Critical issues
(none)

## Important issues
- [F1] fish/.config/fish/functions/gbranch.fish:60 — a failing `git rev-list --count` is skipped by
  `continue`, so `best_count` can stay empty; `:44-46` lets `GBRANCH_BASES` replace the list unchecked.
- [F2] gbranch.fish:27 — cited by the file name alone: `repo_root` is set before the base is known.
- [F3] nosuch/Missing.java:10 — a file that is not in the repository; at 10:30 nothing else is cited.
- [F4] The help text never says what happens when no candidate branch exists.

## Nits
- gbranch.fish:33 — not numbered, so not assembled.
