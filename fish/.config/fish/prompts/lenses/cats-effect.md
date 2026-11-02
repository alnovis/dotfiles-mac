Cats Effect lens. `cats-effect` IO and tagless-final `F[_]` code, `Resource`, fibers, `Ref` / `Deferred` / `Queue`, and fs2 streams on top. The defects are effects that run at the wrong time (eagerly, never, or every time), resources and fibers that leak, and blocking work on the compute pool. Use with the `cats` lens for the type classes.

HARD GATE: first establish the version from the build (sbt `libraryDependencies`, most often; Mill `ivyDeps`; Gradle / Maven coordinates) — `cats-effect` 2.x or 3.x (and fs2 2.x / 3.x with it) — and state it in the review; the two differ in core APIs (`ContextShift`, `Blocker`, `Timer` exist only in 2; `IO.blocking`, `Dispatcher`, `IORuntime` only in 3). For every finding, name the concrete run that goes wrong (the IO sequenced twice, a fiber started and the caller cancelled, the release skipped on error, a blocking call under load) and the consequence: a side effect lost or doubled, a leak, a starved pool, a hang. Advice for the other major version, or a finding resting on a "Not bugs" item below, is wrong — DROP it.

Where to look first (non-exhaustive — reason beyond this list):
- Effects outside the effect type: `IO.pure(sideEffect())` / `F.pure(...)` / `Applicative[F].pure` run the side effect once, at construction; `IO(future)` vs `IO.fromFuture(IO(makeFuture()))` — a `Future` built outside `IO` starts immediately and is not retried or cancelled.
- The opposite: an `IO` / `F` value is a description — `val load = IO(fetch())` sequenced in two places fetches twice. If it must run once, it needs `memoize`, a `Ref` / `Deferred`, or to be run once and its result passed on.
- Blocking on the compute pool: JDBC, file I/O, `Thread.sleep`, a blocking client inside `IO.delay` / `Sync[F].delay`. CE3: `IO.blocking` / `Sync[F].blocking` (`interruptible` for cancellable blocking); CE2: `Blocker` + `ContextShift`.
- Resources: acquire without `Resource` / `bracket`, so an error or cancellation skips the release; a value from `Resource.use` used after `use` returns (the resource is already closed); `allocated` with the release never called.
- Fibers: `start` / `.start` with the fiber never joined or cancelled — its errors are lost and it outlives the caller; `background`, `Supervisor`, `parTraverse`, `race` scope it.
- `Ref`: `get` then `set` is not atomic — use `update` / `modify`; the function given to `modify` / `update` may run more than once (CAS retry) — no side effects inside it (the same in CE2).
- Cancellation: work inside `uncancelable` that can hang; a finalizer (`guarantee`, `onCancel`) that itself blocks; `timeout` on an effect that ignores cancellation (a blocking call not marked `interruptible`).
- `unsafeRunSync` / `unsafeRunAndForget` / `unsafeToFuture` inside library or effect code; a second `IORuntime` created next to the application's. CE3 callbacks from impure APIs go through `Dispatcher`.
- Unbounded `Queue.unbounded` / fs2 `unboundedQueue` between a fast producer and a slow consumer.

By version:
- 2: `ContextShift`, `Timer`, `Blocker`, `IO.shift`, `Bracket`, `Concurrent`, `ConcurrentEffect`; `IO.async` callback without cancellation token.
- 3: `MonadCancel`, `Spawn`, `Concurrent`, `Temporal`, `Sync`, `Async`; `IO.blocking` / `interruptible`; `IORuntime`; `Dispatcher`; `IO.async` returns an optional finalizer.

Not bugs (do not report these):
- An `IO` / `F` value defined and not run on the spot — it is a description, run by the caller.
- Long `flatMap` chains and recursive `IO` loops — stack-safe.
- `IO.delay(println(...))` / `Sync[F].delay(...)` around a side effect — the correct form.
- A method returning `Resource[F, A]` — acquiring happens at `use`, not at the call.
