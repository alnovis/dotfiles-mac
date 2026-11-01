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
- `injection` — input reaching an interpreter unseparated: SQL, shell, XXE, path traversal, CRLF / log forging, ReDoS
- `ssrf` — outbound requests whose URL, host or port the caller controls
- `sensitive-data` — secrets, PII or internals reaching logs, responses, URLs or unprotected storage

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

Shell lenses (original to this repo — two shells, two execution models):
- `bash` — bash / POSIX sh: unquoted expansions, empty variables in destructive paths, `set -e` that does not fire, bashisms under `/bin/sh`
- `fish` — fish footguns (line-split command substitution, vanishing empty lists, block scope, `"\t"`) plus a "Not bugs" list of bash habits models misapply to fish

Data / query lenses (original to this repo — one engine each; the failure modes don't transfer):
- `sql-postgres` — OLTP relational: unbounded scans, missing indexes, locking, unsafe migrations, NULL semantics
- `sql-clickhouse` — OLAP columnar: `ORDER BY`/partition design, mutations, dedup (`FINAL`), memory-blowing joins
- `hbase` — wide-column access patterns: row-key hotspotting, unbounded scans, column-family / version growth
- `redis` — races between commands, non-atomic collection swaps, lost TTLs, cross-slot ops, Sentinel failover, Pub/Sub vs Streams; client section for Jedis / Lettuce / Spring Data Redis / Redisson / redis-rs

Add a lens by dropping a `<name>.md` file here; it becomes selectable immediately
(in `--lens`, its completion, and validation). Keep the shape of the existing
files: a one-line framing, a `HARD GATE:` paragraph, then a
`Where to look first (non-exhaustive — reason beyond this list):` checklist. A
lens may add a "Not bugs" list — idioms or contexts that look wrong to the model but
are correct (`fish`: bash habits; `redis`: test and admin code). A lens whose engine
is used from several clients (`redis`) keeps the engine's failure modes in the main
checklist and adds a short per-client section, rather than one lens per language.

## Attribution

The **security** lenses (`crypto`, `access-control`, `logic-bug`,
`deserialization`, `injection`, `ssrf`, `sensitive-data`) are adapted from Visa's Vulnerability Agentic Harness (VVAH),
specifically its detection skills `vvaharness/skills/<name>/SKILL.md` (before
v1.5.0 they were the `SPECIALIST_HINTS` in `vvaharness/lang/hints.py`). The
sibling sweep and the absence rule in `meta-review*.md` and the `ai-review`
skill are adapted from its `sibling-instances` and `code-exploration` skills.

- Source: https://github.com/visa/visa-vulnerability-agentic-harness
- License: Apache License 2.0, © 2026 Visa, Inc.

Wording has been condensed and re-framed for a general code-review command. The
first four retain VVAH's structure and item set; `injection`, `ssrf` and
`sensitive-data` (v1.5 skills) keep its hard gates, with the checklists cut down
and retargeted at JVM / Rust stacks (`sensitive-data` also takes the
secrets-in-logs class of VVAH's `log-injection`, and `injection` its log forging).
The two security items of `k8s-manifest` (escape hatches, committed `Secret`
data) come from VVAH's `iac` skill.

The **quality** lenses (`documentation`, `reactive`, `resource-leak`,
`error-handling`, `k8s-manifest`), the **Rust** lenses (`rust-unsafe`,
`rust-async`, `rust-ownership`), the **shell** lenses (`bash`, `fish`), and the **data / query** lenses (`sql-postgres`,
`sql-clickhouse`, `hbase`, `redis`) are original to this repository — same HARD GATE
discipline, not derived from VVAH.
