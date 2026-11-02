Scala lens. The language and its standard library, Futures included. The language changed under the same name — 2.11, 2.12, 2.13 and 3 differ in collections, implicits and syntax — and models often read Scala as Java, or one version as another. So this lens is as much about what NOT to report as what to report. Libraries have their own lenses, used on top of this one: `akka` (Akka / Pekko), `cats`, `cats-effect`, `zio`.

HARD GATE: first establish the Scala version from the build (see "Finding the version" below) and state it in the review; never assume one. For every finding, name the concrete input or state (an empty collection, a second thread, a failed Future, a key pushed again) and what the code then does wrong. A finding that rests on another version's semantics, or on a "Not bugs" item below, is wrong — DROP it.

Finding the version (at the reviewed commit — projects upgrade and even change build tools):
- sbt, most projects: `scalaVersion`, `ThisBuild / scalaVersion`, `crossScalaVersions` in `build.sbt` or `project/*.scala` (versions are often `val`s there). Subprojects can set their own — take the version of the module the change is in. `project/build.properties` holds the sbt version, not Scala's. `%%` in `libraryDependencies` adds the Scala suffix itself, so `build.sbt` shows no `_2.12`.
- Mill: `scalaVersion` in `build.sc` / `build.mill`; scala-cli: a `//> using scala` directive.
- Gradle: the `scala-library` / `scala3-library_3` dependency; Maven: `scala.version` or the `_2.11` / `_2.12` / `_2.13` / `_3` suffix of the artifacts in `pom.xml`.

Where to look first (non-exhaustive — reason beyond this list):
- Collection cost on a hot path: `List` append `:+`, `list(i)`, `.length`, `.last`, `contains` are O(n); an immutable collection rebuilt per message or request grows the cost with its size. `Vector` / `ArrayDeque` / a `Map` keyed lookup are the fixes. A collection that is only ever added to (never pruned on every path that removes its twin) is a leak.
- `Array ==` compares references, not contents (`sameElements` / `java.util.Arrays.equals`); arrays as `Map` keys or in case classes break equality.
- Partial operations: `Option.get`, `.head` / `.last` / `.max` on a possibly empty collection, `Map.apply` on a missing key, a `match` that is not exhaustive (non-sealed types fail with `MatchError` at runtime).
- Futures: blocking calls (`Await.result`, JDBC, `Thread.sleep`) on the global or a shared `ExecutionContext` without `blocking {}` or a dedicated pool; a Future started and dropped, so its failure is never seen; `Try` / `catch { case e: Throwable }` that swallows fatal errors or `ControlThrowable`.
- `return` inside a lambda is a non-local return implemented by an exception — a surrounding `catch Throwable` eats it.
- A `var` or mutable collection in an `object` or a shared instance, written from several threads.
- Scala 2: a `lazy val` initializer holds the instance's lock — two threads initializing cyclic lazy vals deadlock.

By version:
- 2.11 / 2.12: `mapValues` / `filterKeys` return a lazy view — the function re-runs on every access (still lazy in 2.13, as `MapView`). `Stream` memoizes: holding its head keeps every element. `JavaConversions` converts implicitly and silently (removed in 2.13; `JavaConverters` / `.asScala` is explicit).
- 2.11: `Either` is not right-biased — `map` / `flatMap` need `.right`; SAM conversion of lambdas to Java interfaces does not exist yet (2.12+).
- 2.12 → 2.13: `scala.Seq` changes from `collection.Seq` (a mutable `ArrayBuffer` passes as `Seq`) to `immutable.Seq`; `Future.onSuccess` / `onFailure` are gone; `.to[List]` becomes `.to(List)`.
- 3: indentation is significant — a re-indented line can fall out of its block and change what runs; `given` / `using` replace implicit values and parameters, and an implicit conversion needs a `Conversion` instance and the `implicitConversions` import; non-local `return` is deprecated; lazy vals no longer lock the instance.

Not bugs (do not report these):
- `xs :+ x` appends at the TAIL; `x +: xs` and `x :: xs` prepend at the head. After a series of `:+`, the head is the OLDEST element and `splitAt(n)` takes the oldest n.
- `var state: List[...]` reassigned with an immutable collection, confined to one thread (an actor's `receive`, a single-threaded loop) — an ordinary idiom, not shared mutable state.
- `==` compares values (structural for case classes, collections and strings) — except arrays, see above.
- No `return` keyword: the last expression is the result. Procedure syntax `def f() { … }` is valid in 2.11 / 2.12 (deprecated in 2.13, dropped in 3).
- Implicit parameters and `given` instances are passed by the compiler — not "missing arguments".
