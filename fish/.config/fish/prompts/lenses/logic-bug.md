Logic-flaw lens. The class of bug that has no single grep signature and only surfaces when you reason about ordering, concurrency, and edge-case inputs.

HARD GATE: for every finding you MUST cite the exact trust boundary crossed — the file:line where untrusted/external input enters, and the file:line where the security or correctness decision is made on that input. If both sides are internal (service-to-service, same trust domain, idempotent retry, intentional design), DROP the finding. No trust-boundary citation → no finding.

Where to look first (non-exhaustive — reason beyond this list):
- Check-then-act (TOCTOU): state validated, then used, with a window where it can change in between.
- Half-authenticated or half-initialized sessions observable under concurrency.
- Integer overflow or narrowing casts producing id collisions or size miscalculations.
- Protocol/state-machine confusion: an operation accepted in a state where it should be rejected.
- Cache keys missing a tenant / user / role dimension → cross-principal data served.
- Sentinel-return misuse: `indexOf`/`find` returning `-1`/`null` used directly as an offset or trusted result.
