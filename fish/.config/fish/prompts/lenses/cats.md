Cats lens. Cats core (`cats`, `cats.data`) — type classes, `Validated`, `Either`, `NonEmpty*`, `Eval`, monad transformers. Defects here are rarely crashes: they are errors silently reduced to the first one, instances that break their laws, and recursion that overflows the stack on large inputs. For effects (`IO`, `Resource`, `Ref`) use the `cats-effect` lens.

HARD GATE: first establish the version from the build (sbt `libraryDependencies`, most often; Mill `ivyDeps`; Gradle / Maven coordinates) — `cats-core` 1.x or 2.x (and the Scala version: 2.11 / 2.12 need `-Ypartial-unification` for most of it) — and state it in the review. For every finding, name the concrete input (two invalid fields, a list of 100 000 elements, values that compare equal but hash differently) and the wrong result: an error lost, a law broken, a stack overflow. Compile-time concerns (ambiguous implicits, a missing import) are not findings — the build would fail. A finding resting on a "Not bugs" item below is wrong — DROP it.

Where to look first (non-exhaustive — reason beyond this list):
- Error accumulation: `Either` / `EitherT` short-circuit on the first `Left` — `mapN`, `traverse`, `sequence` over `Either` report one error. When the caller needs every error (form or request validation), the type must be `Validated` / `ValidatedNel` / `ValidatedNec` (or `parMapN` / `parTraverse` on `Either`, which accumulate through `Parallel`).
- Lawless instances: a hand-written `Semigroup` / `Monoid` whose `combine` is not associative or whose `empty` is not an identity (averages, `max` with a fake zero, last-write-wins on unordered data) — `combineAll`, `foldMap` and parallel folds then depend on grouping. An `Eq` / `Order` inconsistent with `equals` / `hashCode` / `Ordering` used elsewhere for the same type (a `Set` and a `===` that disagree).
- Stack safety: a custom `Monad` whose `tailRecM` is not stack-safe (implemented by plain recursion); `foldRight` / recursion over large structures without `Eval`; deep `flatMap` chains in `State` / `Writer` / `Kleisli` over a non-trampolined base (`Id`) on large inputs.
- Partial operations: `NonEmptyList.fromListUnsafe` / `NonEmptyChain.fromSeq(...).get` on input that can be empty; `Validated` turned to `Either` and back, dropping accumulated errors.
- `EitherT` / `OptionT` stacks where an exception thrown inside `map` escapes the error channel (it becomes a failure of the outer effect, not a `Left`).

By version:
- 1.x: syntax and instances via `import cats.implicits._`; on Scala 2.11 / 2.12 `-Ypartial-unification` is required.
- 2.2+: instances live in implicit scope, `import cats.syntax.all._` is enough; `cats.implicits._` still works. Mixed import styles are a compile issue, not a runtime one.

Not bugs (do not report these):
- `|+|`, `mapN`, `.some`, `.asRight`, `.traverse` syntax — standard, not "obscure".
- Tagless-final `F[_]: Monad` signatures — abstraction, not missing implementation.
- `Id` used as the effect in tests.
- An `Either` that short-circuits where only the first error matters (a pipeline step, a lookup chain).
