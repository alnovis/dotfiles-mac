Akka lens. Akka / Pekko actors (classic and typed), Akka Streams and Akka HTTP. The defects are thread confinement broken outside `receive`, a blocked dispatcher, and messages or streams that silently stop — invisible until load. Classic and typed actors are two different models with different traps — see "Classic vs typed" below; advice for one is often wrong for the other. Use with the `scala` lens for the language itself.

HARD GATE: first establish the version from the build (sbt `libraryDependencies`, most often; Mill `ivyDeps`; Gradle / Maven coordinates) — `akka-actor` / `akka-actor-typed` 2.5, 2.6, 2.7+, or `pekko-actor` (a fork of Akka 2.6, package `org.apache.pekko`) — and whether the code is classic or typed; state it in the review. For every finding, name the concrete message, thread or load that triggers it (a reply arriving after a Future completes, a burst of messages, a slow downstream, a failing child) and the consequence: state corrupted, callers timing out, a stream stalled, a connection pool exhausted. A finding that rests on another version's API or on a "Not bugs" item below is wrong — DROP it.

Where to look first (non-exhaustive — reason beyond this list):
- Confinement: actor state, `sender()` or `context` used from a `Future` callback, a scheduled closure or another thread. `sender()` there is whoever sent the CURRENT message, or `deadLetters`. Capture `val s = sender()` first, `pipeTo` the result back (classic), `context.pipeToSelf` (typed).
- Blocking inside `receive` / a behavior (JDBC, `Await.result`, `Thread.sleep`, a blocking client) stalls the dispatcher thread and every actor sharing it; it belongs on a dedicated blocking dispatcher.
- `ask` (`?`): the timeout is a failure that must be handled; an `ask` from inside an actor followed by `Await` blocks it. One slow actor behind `ask` makes every caller time out.
- Unbounded growth: the default mailbox is unbounded — a slow actor under a fast producer grows memory without backpressure (stash: see below).
- Supervision: classic actors restart by default on any exception, typed actors stop (details below). A failure inside a Future the actor started never reaches its supervisor.
- `context.watch` without handling `Terminated` (a classic `receive` case, a typed `receiveSignal`): when the watched actor stops, the watcher fails with `DeathPactException` — in both models.
- Lifecycle: resources opened in an actor and not released in `postStop`; classic `scheduler.schedule…` not cancelled on stop (prefer `Timers`, which are cancelled with the actor).
- Messages: mutable objects sent between actors are shared state across threads.
- Streams: a graph built but never run; `Sink.ignore` / `runForeach` whose completion `Future` is dropped, so a failure is never seen; `mapAsync` parallelism unbounded against an external service; `Source.queue` overflow strategy that drops or fails silently; blocking inside a stage.
- Akka HTTP: a response entity not consumed (`discardEntityBytes` / `toStrict`) holds the pooled connection — the client pool stalls.

Classic vs typed:
- Classic (called "untyped" before 2.6): `Actor` with `receive: Receive` takes `Any`. A message of the wrong type compiles and at runtime falls into `unhandled` — dead letters, no error. `sender()` is implicit and valid only for the current message. A restart resets state and drops the failing message; with the default strategy a poison message loops. `Stash` is unbounded and needs a deque-based mailbox.
- Typed: `Behavior[T]` and `ActorRef[T]` — the compiler checks message types, and there is NO `sender()`: replies go to a `replyTo: ActorRef[Reply]` carried in the message. A behavior that forgets to reply leaves the asker to time out, and no compiler catches it. Restart (when a `supervise` asks for it) re-runs `Behaviors.setup` — state held in its closure starts over. `StashBuffer` has a capacity: past it, `StashOverflowException`. `ask` from outside an actor (`AskPattern`) needs an implicit `Timeout` and `Scheduler`; `context.ask` inside an actor maps the reply (or the timeout) to the actor's own message type, and that mapping must handle the failure.
- Mixed code: `toTyped` / `toClassic` adapters cross the models — a typed ref turned classic loses its message-type check; a classic actor replying to a typed `replyTo` must send exactly the reply type.

By version:
- 2.5: typed is experimental; a stream needs an explicit `ActorMaterializer`; `scheduler.schedule` is current.
- 2.6: typed is the default API; the materializer comes from the `ActorSystem`; `schedule` is deprecated for `scheduleWithFixedDelay` / `scheduleAtFixedRate` (different behaviour when a run is late).
- 2.7+: licence changed (BSL); Pekko 1.x keeps the 2.6 API under `org.apache.pekko` — advice for one applies to the other modulo the package.

Not bugs (do not report these):
- `var` fields or mutable collections read and written only inside `receive` / the behavior — one message at a time, no race.
- `sender()` used synchronously inside a classic `receive` (reply before returning).
- No `sender()` in typed code — replies through `replyTo` are the design, not a missing feature.
- `context.become` / returning a new `Behavior` to change state — the idiom, not "mutable state".
- A typed behavior returning `Behaviors.same` / `Behaviors.unhandled`.
