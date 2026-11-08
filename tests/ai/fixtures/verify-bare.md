- `gbranch.fish:8` — the help text overstates the auto-detection — REFUTED 8/10
  why: the candidates loop tries every listed branch; a why line that ends in the word is not counted as REFUTED
- **`gbranch.fish:44` — GBRANCH_BASES is read unvalidated** — UNCERTAIN 5/10
  why: needs the caller's environment.
- **`gbranch.fish:61` — the last fallback is dead** The loop returns on the first branch it finds, so the last one is never tried. **CONFIRMED 7/10**

Verify: 1 confirmed, 1 refuted, 1 uncertain
