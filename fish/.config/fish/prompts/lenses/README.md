# Review lenses

Optional specialist checklists for `ai review --lens NAME[,NAME...]`. Each file
is a focused hunting checklist for one class of defect, injected after the base
review prompt. A lens tells the model *where to look*; the finding gate and
severity rules in `meta-review*.md` still apply — a lens is not a mandate to find
something. Each lens ends with a HARD GATE: evidence a finding must carry, and the
conditions under which it must be dropped.

Security lenses (adapted from VVAH — see Attribution):
- `crypto` — cryptographic misuse an attacker can exploit mathematically or via protocol negotiation
- `access-control` — missing authorization / ownership checks (IDOR, BOLA, privilege escalation)
- `logic-bug` — ordering, concurrency, and edge-case flaws with no single grep signature
- `deserialization` — untrusted-input deserialization leading to RCE (JVM-focused)

Quality lenses (original to this repo — general correctness / maintainability):
- `documentation` — docs, comments, and examples that drift from what the code does
- `reactive` — Reactor / reactive-streams footguns (blocking a non-blocking pipeline, lost signals; Kafka)
- `resource-leak` — handles not released on every path, including the error path (JVM, Reactor lifecycles)
- `error-handling` — swallowed, mislabeled, or crash-on-recoverable failures (Scala/Java/Kotlin/Rust)
- `k8s-manifest` — deployment-safety defects in k8s / jkube YAML (probes, limits, image tags, secrets)

Rust lenses (original to this repo — Rust-specific classes not covered above):
- `rust-unsafe` — undefined behavior / broken safety invariants behind `unsafe`, or unsound safe APIs
- `rust-async` — tokio / async-runtime footguns (lock across `.await`, blocking the executor, dropped tasks)
- `rust-ownership` — leaks (`Rc` cycles), runtime borrow panics, Drop-order and needless-allocation costs

Data / query lenses (original to this repo — one engine each; the failure modes don't transfer):
- `sql-postgres` — OLTP relational: unbounded scans, missing indexes, locking, unsafe migrations, NULL semantics
- `sql-clickhouse` — OLAP columnar: `ORDER BY`/partition design, mutations, dedup (`FINAL`), memory-blowing joins
- `hbase` — wide-column access patterns: row-key hotspotting, unbounded scans, column-family / version growth

Add a lens by dropping a `<name>.md` file here; it becomes selectable immediately
(in `--lens`, its completion, and validation). Keep the shape of the existing
files: a one-line framing, a `HARD GATE:` paragraph, then a
`Where to look first (non-exhaustive — reason beyond this list):` checklist.

## Attribution

The **security** lenses (`crypto`, `access-control`, `logic-bug`,
`deserialization`) are adapted from Visa's Vulnerability Agentic Harness (VVAH),
specifically its `SPECIALIST_HINTS` lenses in `vvaharness/lang/hints.py`.

- Source: https://github.com/visa/visa-vulnerability-agentic-harness
- License: Apache License 2.0, © 2026 Visa, Inc.

Wording has been condensed and re-framed for a general code-review command; the
hunting checklists retain VVAH's structure and item set.

The **quality** lenses (`documentation`, `reactive`, `resource-leak`,
`error-handling`, `k8s-manifest`), the **Rust** lenses (`rust-unsafe`,
`rust-async`, `rust-ownership`), and the **data / query** lenses (`sql-postgres`,
`sql-clickhouse`, `hbase`) are original to this repository — same HARD GATE
discipline, not derived from VVAH.
