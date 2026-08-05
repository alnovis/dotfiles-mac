Resource-leak lens. Handles that must be released but aren't on every path — including the error path. Mostly JVM (this stack), plus Reactor lifecycles.

HARD GATE: for every finding, name the resource, its acquisition file:line, and the path on which it is NOT released (early return, thrown exception, untaken branch). If a `try-with-resources` / Kotlin `use {}` / Scala `Using` / RAII owner or a framework-managed lifecycle already covers every path, DROP it. A resource freed on the happy path but leaked on throw IS a finding.

Where to look first (non-exhaustive — reason beyond this list):
- `InputStream`/`OutputStream`/`Reader`/`Writer`, JDBC `Connection`/`Statement`/`ResultSet`, or a socket opened without try-with-resources / `Using` / `use`.
- Kafka `Producer`/`Consumer`, `WebClient`/HTTP client, or a connection pool created per-call instead of shared — or created and never closed.
- Reactor `Disposable` from `subscribe()` never disposed; a long-lived `Flux` with no cancellation.
- `ExecutorService` / thread pool created and never `shutdown()`.
- Lock or semaphore acquired without a `finally` release — a throw between acquire and release strands it.
- Temp file, native handle, or memory-mapped buffer not cleaned up.
- Scala `Source.fromX` (or similar) without a matching `.close()` / bracket around it.
