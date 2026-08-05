Error-handling lens. Failures that are swallowed, mislabeled, or turned into a worse failure than the original. The defect is losing information about a failure, or crashing where recovery was intended.

HARD GATE: for every finding, cite the file:line where the error is dropped or mishandled and state what is lost — a swallowed exception, an unchecked `null`/`None`, a panic on recoverable input, or a masked root cause. If the swallow is deliberate and documented (comment, sentinel, known-benign), or the value is provably non-fallible, DROP it. An empty catch with a comment explaining why is not a finding.

Where to look first (non-exhaustive — reason beyond this list):
- Empty `catch {}`, or catch-log-and-continue that leaves the program in an invalid state.
- Catching `Throwable`/`Exception` broadly and hiding `InterruptedException`, `Error`, or cancellation.
- Rust `.unwrap()`/`.expect()`/`panic!` on fallible input outside tests/`main`; a real error masked by an over-broad `From`.
- Scala/Java `.get` on `Option`/`Optional`/`Try`/`Either` with no prior check; `Await.result` with no timeout.
- Kotlin `!!` on a nullable that can actually be null; `runCatching` whose result is never inspected.
- Exception rethrown without its cause (`throw new X(e.getMessage())` drops the stack trace).
- Kafka / reactive: no poison-message or dead-letter path — one bad record halts consumption.
- Failure surfaced at the wrong level — a real failure logged at DEBUG, or a benign one at ERROR.
