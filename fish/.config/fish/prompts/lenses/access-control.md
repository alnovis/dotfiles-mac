Access-control lens. The bug here is usually the ABSENCE of a check — you are looking for what is NOT there. Or the check exists but guards the wrong thing.

HARD GATE: for every finding, show (a) the entry point and who is proven to be calling: the authenticated identity of a request; for a webhook, the source proven by its signature or secret token; for a message consumer, the trusted topic or producer, never a tenant or user id read from the payload; and (b) where ownership / tenant / role is verified for THAT specific object, by the same id that is then used. If (b) exists, checks the id that is used, and runs before the effect it guards, DROP the finding. "Endpoint requires login" is NOT authorization. A fixed or hardcoded target id (bounded blast radius) is NOT IDOR/BOLA.

A check counts only where you can see it: in the diff, the code shown, or through your tools. It often sits outside the changed code: a security filter chain or a request filter, an aspect or middleware, a guard on an interface or a base class, a row-level policy in a database migration, an ORM tenant filter. Look there before calling it absent, and name where you looked. A check that could only live where the repository cannot show it (an API gateway, an ingress) is not a defence you saw: report the finding, name the control you could not see, and place it one tier lower.

Where to look first (non-exhaustive — reason beyond this list):
- IDOR / BOLA: an object id from the request is used to fetch/mutate without checking the caller owns it.
- The check is there but on the wrong thing: ownership verified for one id while another is used (the path id checked, the id in the body written); the check placed after the effect it should guard. A window between the check and the use is a race: the `logic-bug` lens.
- Missing method guards (`@PreAuthorize`, `@Secured`, route middleware) on a privileged action.
- Vertical escalation: a normal user reaching an admin-only operation.
- Mass assignment: request body binds fields it shouldn't (`owner_id`, `role`, `isAdmin`, `price`, `tenant_id`).
- Multi-tenant leakage: query filters by object id but not by `tenant_id`/`org_id`; a cache keyed without the tenant / user / role, so the first, authorized request fills it and later callers read another principal's data.
- Entry points beyond HTTP: a webhook route open to anyone with no signature or secret-token check; a message consumer that trusts the tenant or user id in the payload; a GraphQL resolver without the guard its REST twin has; a scheduled job that acts with system rights on data from an untrusted source.
- Unscoped destructive bulk ops (`deleteAll`, `DELETE FROM ... ` with no WHERE) reachable from a request — treat as high-impact.

A pair to calibrate on (pseudo-code; judge real code the same way):
- Not a finding: the handler `update order {id}` changes with no guard in the diff, and the code shown has a middleware registered for every `/orders/*` route that loads the order by `{id}` and rejects a caller who does not own it. The check exists, outside the diff: DROP.
- A finding: the handler checks `owns(user, path.id)`, then saves `body`, whose `id` the caller sets. Ownership was proven for the path id; the write goes to the body id. Report it, citing both lines.
