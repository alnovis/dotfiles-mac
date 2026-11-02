## Run 1/2

## Summary
- A summary bullet is not a finding.

## Critical issues
- `a.fish:3` — a dash bullet.
  - an indented sub-bullet belongs to the finding above

## Important issues
* `b.fish:7` — a star bullet.

## Removed code
- `old.fish` — removed code still gets a number.

## Nits
- (none)
- `d.fish:1` — a nit is not numbered: it gets no verdict.

## Bugs
- `e.fish:2` — a section the model named its own way is still numbered.

## Run 2/2

1. **Summary** — the summary as a numbered bold heading.

2. **Critical issues**

1. **Lost updates** — a numbered finding that starts in bold is a finding, not a heading.

**3. Important issues**

- `c.fish:9` — under a bold numbered heading.

**4. Strengths**

- A strength is not numbered.

5. **Tests**
   - `t.fish:4` — an indented bullet right under a numbered bold heading is a finding.
   - `t.fish:8` — and so is its sibling.

6. **Nits**
   - `n.fish:2` — an indented nit is still not numbered.

## Run 3/3

1. Summary
- A plain numbered summary heading: its bullet is not a finding.

2. Critical issues — (none)

3. Important issues
- `p.fish:5` — a finding under a plain numbered heading.
1. Tests are missing for p.fish — a numbered item that is not a section name alone is a finding.

5. Removed code
- (none) — the removed check is covered elsewhere: a "(none)" with a note is not a finding.
- None — the same in another spelling.
- Nonexistent `r.fish` is still read: a word that starts with "none" is a finding.

6. Nits:
- `q.fish:1` — a nit under "6. Nits:" is not numbered.

Plain text outside any bullet stays as it is.
