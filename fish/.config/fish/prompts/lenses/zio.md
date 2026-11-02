ZIO lens. ZIO effects, fibers, `Ref` / `Queue` / `Hub`, resources and layers, and ZIO Streams. The defects are effects that run at the wrong time, typed failures turned into defects (or swallowed), fibers interrupted too early or leaked, and blocking work on the default executor.

HARD GATE: first establish the version from the build (sbt `libraryDependencies`, most often; Mill `ivyDeps`; Gradle / Maven coordinates) — `zio` 1.x or 2.x — and state it in the review; the two differ in core APIs (1: `Has`, `ZManaged`, `effect` / `effectTotal`, `Blocking` in the environment; 2: `Scope`, `attempt` / `succeed`, `ZIO.service`, `ZIO.blocking`). For every finding, name the concrete run that goes wrong (the effect sequenced twice, the parent fiber finishing, a release skipped on interruption, a blocking call under load, an exception thrown inside `succeed`) and the consequence: a lost or doubled effect, a leak, a starved executor, a failure the caller cannot catch. Advice for the other major version, or a finding resting on a "Not bugs" item below, is wrong — DROP it.

Where to look first (non-exhaustive — reason beyond this list):
- Throwing code in an infallible constructor: an exception inside `ZIO.succeed` (2) / `effectTotal` (1) is a DEFECT, not a typed failure — `catchAll` / `orElse` do not see it. Throwing code belongs in `ZIO.attempt` (2) / `ZIO.effect` (1).
- Strict vs lazy: `ZIO.succeedNow` evaluates its argument at construction; a side effect there runs once, outside the effect. Conversely an effect value sequenced twice runs twice — memoize (`.memoize`, a `Ref`, a `Promise`) when it must run once.
- Errors: `orDie` / `.refineOrDie` turning recoverable failures into defects; `catchAll` / `.ignore` / `.either` followed by dropping the `Left`; `timeout` returning `Option` with the `None` ignored.
- Blocking on the default executor: JDBC, file I/O, `Thread.sleep`, blocking clients inside `ZIO.attempt` / `succeed`. 2: `ZIO.attemptBlocking` / `ZIO.blocking`; 1: `blocking.effectBlocking` with `Blocking` in the environment.
- Fibers: `fork` children are supervised — interrupted when the parent fiber ends. A background job meant to outlive the request needs `forkDaemon` / `forkScoped` / `forkIn`; a fiber that should end with the request but is `forkDaemon` leaks. A forked fiber never joined loses its failure.
- Resources: acquire without `acquireRelease` (2) / `ZManaged` / `bracket` (1), so interruption skips the release; a resource used after `ZIO.scoped` (2) / `use` (1) closes it.
- `Ref.modify` / `update`: the function must be pure — effectful updates need `Ref.Synchronized` (2) / `RefM` (1); `get` then `set` is not atomic.
- Interruption: long work inside `uninterruptible` regions; finalizers (`ensuring`, `onInterrupt`) that block or fail.
- Layers: a layer built per use instead of shared (two connection pools; `.fresh` duplicates on purpose); services constructed outside a layer and never closed.
- `Unsafe.run` / `Runtime.default.unsafeRun` inside effects or library code; unbounded `Queue.unbounded` / `Hub.unbounded` under a fast producer.

By version:
- 1: `ZIO.effect` / `effectTotal` / `effectSuspend`, `ZManaged`, `Has[A]`, `ZIO.accessM`, `Blocking` / `Clock` / `Console` as environment services, `RefM`.
- 2: `ZIO.attempt` / `succeed` / `suspend`, `Scope` + `acquireRelease` + `ZIO.scoped`, `ZIO.service` / `serviceWithZIO`, no `Has`, `Clock` / `Console` built in, `Ref.Synchronized`, `Unsafe` for running.

Not bugs (do not report these):
- An effect value defined and not run on the spot — it is a description.
- `for` comprehensions over effects, and long `flatMap` chains — stack-safe.
- An `R` type parameter listing services — dependency declaration, provided by layers, not "missing arguments".
- `UIO` / `URIO` / `Task` / `RIO` aliases.
