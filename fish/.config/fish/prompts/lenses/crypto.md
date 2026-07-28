Cryptography lens. Target weaknesses an attacker can exploit mathematically or by abusing protocol negotiation — not generic "uses MD5 somewhere" hygiene items.

HARD GATE: report a finding only when you can name what the attacker gains — forgery, decryption, key recovery, signature/auth bypass. "Weak algorithm is present" with no exploitation path is not a finding.

Where to look first (non-exhaustive — reason beyond this list):
- Non-constant-time comparison of secrets, MACs, or tokens (timing oracle).
- JWT algorithm confusion: `alg=none` accepted, HS↔RS key confusion, `kid` header used for path/key lookup (traversal).
- IV/nonce reuse — especially GCM nonce reuse, which fully breaks authenticity, not just confidentiality.
- Non-CSPRNG randomness for tokens, IVs, salts, OTPs, session ids (`Random`, `Math.random`, time-seeded PRNGs).
- TLS verification wired up but not enforced (custom `TrustManager`/`HostnameVerifier` that accepts everything; verification toggled off by config).
- Hardcoded keys, salts, or IVs committed to the repo.
- Encrypt-without-authenticate (CBC/CTR with no MAC), or verify-after-use ordering.
