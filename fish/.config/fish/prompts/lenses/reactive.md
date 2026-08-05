Reactive lens. Footguns specific to Reactor / reactive-streams pipelines (Mono/Flux, WebFlux, reactive Kafka). The defect is breaking the non-blocking contract or losing a signal — usually invisible until load or failure.

HARD GATE: for every finding, cite the file:line where the reactive contract is broken AND name the concrete consequence — thread starvation, dropped element, silently swallowed error, unbounded buffer, or a stream that never runs. If the call sits on `boundedElastic`/a blocking scheduler by design, or the publisher is provably subscribed downstream, DROP the finding. "Uses Reactor" is not a defect; a broken signal path is.

Where to look first (non-exhaustive — reason beyond this list):
- `.block()`, `.blockFirst()`, `.toFuture().get()`, blocking JDBC/HTTP, or `Thread.sleep` executed on an event-loop / `parallel` scheduler.
- A `Mono`/`Flux` built but never subscribed or returned — the work never happens.
- `subscribe()` invoked inside another operator (nested subscribe) instead of composing with `flatMap`/`concatMap`.
- `onError` unhandled: no `onErrorResume`/`onErrorContinue`/`doOnError`, so one failure silently terminates the stream — a poison Kafka record kills the consumer.
- `flatMap` with unbounded concurrency over an external call → connection-pool exhaustion; `flatMap` where ordering is required and `concatMap` was meant.
- Shared mutable state mutated across operators / schedulers without confinement.
- `Disposable` from `subscribe()` discarded → no cancellation or cleanup (see the resource-leak lens).
- Reactor Context / MDC dropped across an async boundary → correlation id missing downstream in logs.
