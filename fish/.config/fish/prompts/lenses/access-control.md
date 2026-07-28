Access-control lens. The bug here is usually the ABSENCE of a check — you are looking for what is NOT there.

HARD GATE: for every finding, show (a) the entry point and the authenticated identity it carries, and (b) where ownership / tenant / role is verified for THAT specific object. If (b) exists and is correct, DROP the finding. "Endpoint requires login" is NOT authorization. A fixed or hardcoded target id (bounded blast radius) is NOT IDOR/BOLA.

Where to look first (non-exhaustive — reason beyond this list):
- IDOR / BOLA: an object id from the request is used to fetch/mutate without checking the caller owns it.
- Missing method guards (`@PreAuthorize`, `@Secured`, route middleware) on a privileged action.
- Vertical escalation: a normal user reaching an admin-only operation.
- Mass assignment: request body binds fields it shouldn't (`owner_id`, `role`, `isAdmin`, `price`, `tenant_id`).
- Multi-tenant leakage: query filters by object id but not by `tenant_id`/`org_id`.
- Unscoped destructive bulk ops (`deleteAll`, `DELETE FROM ... ` with no WHERE) reachable from a request — treat as high-impact.
