Sensitive-data lens. Places where the application reveals more than it should — to the caller, to logs, or at rest. Point-of-occurrence: no injection path is needed, only sensitive data reaching a readable channel.

HARD GATE: a finding needs BOTH — (a) genuinely sensitive data: credentials, tokens, keys, PII (card number, account, ID number, health data), or internals that help an attacker (stack traces, SQL text, server paths, versions); and (b) a channel someone unintended can read: response body or header, error page, log line, URL or query string, temp file, cache, or an unauthenticated debug/metrics endpoint. A sensitive-looking NAME is not sensitive CONTENT (`tokenCount`, `passwordPolicy`) — read the value that flows. Env/vault lookups and `${VAR}` placeholders are indirection, not literals. An endpoint bound to localhost or behind auth is not exposure.

Where to look first (non-exhaustive — reason beyond this list):
- Log calls carrying secrets: password, token, API key, `Authorization` header, a whole request/DTO/config object whose `toString` (Scala case class, Kotlin data class, Lombok `@Data`, Rust `#[derive(Debug)]`) prints a secret field.
- Exceptions to the client: stack trace, SQL error or internal message rendered into the response; framework debug/error detail switched on outside dev.
- Whole-object serialization: an entity returned or serialized as-is with fields the caller must not see (`passwordHash`, `isAdmin`, internal ids, another tenant's data).
- Secrets in URLs (query-string tokens end up in access logs, proxies, browser history) or in error messages and metrics labels.
- Passwords stored with no slow KDF (plain, unsalted, or a fast hash like SHA-256) — the absence of bcrypt/scrypt/argon2/PBKDF2 is the finding.
- Exposed actuator/admin/debug routes (`/actuator/env`, `/heapdump`, JMX, pprof) reachable without auth.
- Authenticated responses cacheable by proxies (no `Cache-Control: no-store`); HTTPS service with no HSTS.
- Severity follows blast radius: one user's field in a log is medium; every user's card number in a readable store is high.
