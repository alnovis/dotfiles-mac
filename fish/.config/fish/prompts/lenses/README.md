# Security review lenses

Optional specialist checklists for `ai review --lens NAME[,NAME...]`. Each file
is a focused hunting checklist for one class of vulnerability, injected after the
base review prompt. A lens tells the model *where to look*; the finding gate and
severity rules in `meta-review*.md` still apply — a lens is not a mandate to find
something.

Available lenses:
- `crypto` — cryptographic misuse an attacker can exploit mathematically or via protocol negotiation
- `access-control` — missing authorization / ownership checks (IDOR, BOLA, privilege escalation)
- `logic-bug` — ordering, concurrency, and edge-case flaws with no single grep signature
- `deserialization` — untrusted-input deserialization leading to RCE (JVM-focused)

Add a lens by dropping a `<name>.md` file here; it becomes selectable immediately.

## Attribution

The checklists in this directory are adapted from Visa's Vulnerability Agentic
Harness (VVAH), specifically its `SPECIALIST_HINTS` lenses in `vvaharness/lang/hints.py`.

- Source: https://github.com/visa/visa-vulnerability-agentic-harness
- License: Apache License 2.0, © 2026 Visa, Inc.

Wording has been condensed and re-framed for a general code-review command; the
hunting checklists retain VVAH's structure and item set.
