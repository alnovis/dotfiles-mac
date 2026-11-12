Logic-flaw lens. The class of bug that has no single grep signature and only surfaces when you reason about ordering, concurrency, state that outlives a call, and edge-case inputs.

HARD GATE, by what the finding claims:
- Security (an attacker gains something): you MUST cite the exact trust boundary crossed — the file:line where untrusted/external input enters, and the file:line where the security decision is made on that input. If both sides are internal (service-to-service, same trust domain), it is not a security finding.
- Correctness (a wrong result, work lost or skipped, corrupted state, unbounded growth): no attacker is needed. Name the production trigger (a second scan, request or event; a retry; two threads at once; a restart; an empty or unexpected value), the file:line where the state or the decision goes wrong, and the concrete consequence. No trigger that really happens: no finding.
A guess at the author's intent is no reason to drop a finding. "Intended" needs evidence for that very effect: a comment or doc that says it, a test that asserts it, or the old code doing the same.

Where to look first (non-exhaustive — reason beyond this list):
- Check-then-act (TOCTOU): state validated, then used, with a window where it can change in between.
- Half-authenticated or half-initialized sessions observable under concurrency.
- Integer overflow or narrowing casts producing id collisions or size miscalculations.
- Protocol/state-machine confusion: an operation accepted in a state where it should be rejected.
- Cache keys missing a tenant / user / role dimension → cross-principal data served.
- Sentinel-return misuse: `indexOf`/`find` returning `-1`/`null` used directly as an offset or trusted result.
- State that outlives one call (a map, a cache, a dedup set, a flag on a singleton bean): what does the second call, scan or event do differently from the first? A new guard that skips work the old code did on every pass (a reminder, a notification, a retry) changes behaviour: report it unless the change shows the skip is wanted. State that only grows (no eviction, no TTL, keyed by ids that keep coming) is unbounded memory.
