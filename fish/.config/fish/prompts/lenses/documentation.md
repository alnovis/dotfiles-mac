Documentation lens. The defect here is DRIFT — docs, comments, or examples that contradict what the code actually does, or that are missing where their absence will mislead. You are comparing stated behavior against real behavior.

HARD GATE: for every finding, cite (a) the doc/comment file:line making the claim (or the public surface that lacks one), and (b) the code file:line that contradicts it or is left unserved. If the doc merely reads awkwardly but is technically correct, DROP it — prose style is not a finding. Absence of a doc is a finding ONLY for a public/exported surface or a non-obvious contract, never for self-evident code.

Where to look first (non-exhaustive — reason beyond this list):
- Comment or docstring stating a behavior, default, unit, or range the code no longer honors (stale after a change).
- README / usage example referencing a removed flag, renamed command, or signature that no longer compiles or runs.
- Public/exported function, endpoint, or config key with a non-obvious contract and no doc (nullability, side effects, thread-safety, units, valid range).
- Documented default that disagrees with the actual default in code or config.
- `@param`/`@return`/`@throws` (or Scaladoc/KDoc) naming arguments, exceptions, or types that don't match the signature.
- TODO/FIXME describing a constraint that is silently violated elsewhere in the diff.
- Changelog / migration note promising a behavior the change does not actually deliver.
