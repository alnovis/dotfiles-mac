# AI toolkit docs

- [Architecture](architecture.md) — executors (native ollama driver, runners pi / opencode /
  claude), runner contract, context policy, config resolution, skills, invariants
- [Toolkit reference](toolkit.md) — every command and flag, config keys, env vars, files,
  completion, error messages
- [How-to / best practices](howto.md) — first run, picking and trying models, review workflows,
  cloud providers through the runner, off-network fallback, `ai code` / `ai chat`, troubleshooting

Tests: `tests/ai/run.fish` (golden + smoke harness, offline).
