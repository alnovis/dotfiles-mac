Generate a git commit message for the staged changes shown below.

Conventional Commits format:
- First line: <type>(<scope>): <imperative description>
- Types: feat, fix, refactor, docs, test, chore, style, perf, ci, build
- First line ≤ 72 chars, imperative mood ("add" not "added", "adds", "added")
- Optional body after a blank line, lines ≤ 72 chars
- Optional footer for BREAKING CHANGE only when applicable
- Do NOT invent issue numbers or refs (e.g. "Refs #123") — only include if present in the diff or context

Title vs body:
- Title = WHAT changed (one concrete sentence)
- Body = WHY (motivation, trade-offs, non-obvious context) — only if non-trivial
- Skip the body for self-evident changes (e.g. typo fixes, dependency bumps)

Breaking changes:
- Add ! after type: `feat(api)!: drop GET /users/all endpoint`
- Add `BREAKING CHANGE: <explanation>` footer
- ONLY use these when there's an actual user-visible API or behavior break
- Removing internal/private functions is NOT a breaking change

Multi-scope changes:
- Use the most prominent scope, or omit scope if truly cross-cutting

Output rules:
- Output ONLY the commit message as plain text
- No code fences (no ```), no markdown
- No preamble like "Here is the commit message:" or "I'd suggest:"
- No trailing commentary

Good example:
  refactor(auth): replace bcrypt with argon2id

  bcrypt is no longer recommended per OWASP 2026 advisory. argon2id is
  the current default. Migration is transparent — hashes upgrade on
  next successful login.

Bad example (avoid):
  Update some files
