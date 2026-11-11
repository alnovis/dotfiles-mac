Java FP lens. Imperative Java in the changed code that a functional form would make shorter or safer: mutable accumulators, `null` as "absent", flags and `if` chains over a closed set of cases, mutable data carriers, exceptions used for control flow. Unlike the other lenses, most of what it finds is not a defect but a rewrite to suggest — so each finding must carry the rewrite, and the bar is that the new form is plainly better, not merely different.

HARD GATE: first establish the Java version from the build (see "Finding the version" below) and state it in the review; never suggest an API the project's version does not have, nor a library it does not depend on (Vavr, Guava, Functional Java — only if the build has it). Every suggestion cites the file:line of changed code, shows the current shape in a line or two, and gives the rewrite as a short code sketch that compiles on that version and keeps the behaviour: the same result, the same order, the same exceptions, the same side effects, the same laziness or eagerness. A rewrite that is not shorter and removes no concrete risk — a mutation shared across code, a `null` that can escape, a case that can be forgotten — is taste: DROP it. Code outside the diff is not a finding.

Where the findings go:
- A suggestion goes in its own section, `## FP style`, after Removed code: one bullet per site, with the file:line, the current shape and the rewrite sketch. Its severity is nit.
- What the lens turns up that is a real defect (a side effect inside a stream lambda, a `.get()` on an `Optional` that can be empty) goes in Critical or Important like any finding, gated as one.

For verify: a suggestion is CONFIRMED only when the rewrite is equivalent (results, order, exceptions, side effects) and compiles on the project's Java version; REFUTED when it changes behaviour, needs an API or library the project lacks, or is no shorter and removes no risk. That the rewrite is more elegant is not enough. REFUTED also when it goes the other way — a stream, `Optional` chain or `switch` expression turned into a loop or an `if` chain — however equivalent: that is not this lens's suggestion.

Finding the version (at the reviewed commit):
- Maven: `<java.version>` (Spring Boot), `<maven.compiler.release>` / `<release>`, or `<source>` / `<maven.compiler.source>` in `pom.xml`; a module can override the parent.
- Gradle: `java { toolchain { languageVersion = JavaLanguageVersion.of(N) } }`, `sourceCompatibility` / `release` in `build.gradle(.kts)`.
- No build file: say so and suggest nothing newer than Java 8.
- A build file you cannot see (not in the prompt, and no tools to read it): do not try to open it. Say the version is unknown, and suggest nothing newer than Java 8.

Where to look first (non-exhaustive — reason beyond this list):
- A loop that fills a list, set, map or counter: `stream()` with `map` / `filter` / `collect` (`Collectors.groupingBy`, `toMap`, `partitioningBy`, `joining`), `Stream.toList()` (16+), `IntStream` for index ranges. Mind `toMap` throwing on duplicate keys where the loop overwrote — give the merge function.
- A method returning `null` for "not found", and callers that check it: return `Optional<T>`; chain `map` / `flatMap` / `filter` / `orElse` / `orElseGet` / `orElseThrow`, and `or` / `ifPresentOrElse` / `stream` (9+), instead of `isPresent()` then `get()`.
- A status, type or kind modelled as strings, ints or a `Set` of constants with a fall-through default: an `enum`, or a `sealed` interface with `record` cases (17+), and a `switch` expression (14+) with pattern matching (21+) that the compiler checks for exhaustiveness — an unhandled case becomes a compile error instead of a silent default. Name the case the current default swallows, if there is one.
- `instanceof` then a cast: pattern matching `if (x instanceof Foo f)` (16+), record patterns `case Point(var x, var y)` (21+).
- A mutable data carrier (fields, getters, setters, `equals` / `hashCode` by hand) that is only ever built and read: a `record` (16+), with a compact constructor for validation. Copies with one field changed: a `withX` method rather than setters.
- A collection handed out or kept that callers must not change: `List.of` / `Map.of` / `Set.of` (9+), `List.copyOf` (10+), `Collectors.toUnmodifiableList` (10+), `Stream.toList()` (16+).
- A local assigned in several branches then used once: a `switch` expression or a ternary, so it is assigned once and can be `final`.
- Exceptions thrown and caught in the same method to steer the flow, or `try` around parsing to get a default: return a value (`Optional`, a result `record`, a sealed `Success` / `Failure`).
- Side effects in stream lambdas — `forEach` that writes to an outer collection, `peek` that does work, `map` that mutates — are a defect, not style: the result depends on evaluation order and breaks under `parallel()`. Report it with the side-effect-free rewrite.
- `Optional` as a field, a method parameter or a collection element is misuse: suggest `null`-free design (an overload, an empty collection) instead.
- `list.get(0)` / `list.get(list.size() - 1)`: `getFirst()` / `getLast()` (21+, SequencedCollection).

Not findings (do not report these):
- A loop with an early `break` / `return`, a checked exception inside, index arithmetic over several arrays, or a counter updated in several places — the stream version is longer or needs workarounds (`takeWhile`, wrapping checked exceptions). Leave it.
- A loop on a hot path or over primitives where the stream would box or allocate per element, unless the code is clearly not hot.
- A rewrite the other way: a stream, an `Optional` chain or a `switch` expression turned into a loop, `null` checks or an `if` chain — even when it is shorter or allocates less. The lens goes one way, imperative to functional; `## FP style` carries only functional rewrites. A stream's cost on a proven hot path is a performance note, not FP style.
- `for` over a collection that only calls one method per element (`for (var x : xs) send(x)`) — `xs.forEach(this::send)` is not better.
- `var` versus an explicit type, method references versus lambdas, `Stream.of` versus `Arrays.stream` — taste.
- Mutable state confined to one method or one thread (a `StringBuilder`, a local `ArrayList` returned at the end) — the mutation is not shared; only suggest a rewrite when it is also shorter.
- Framework-shaped classes: JPA entities need a no-arg constructor and mutable fields, Spring `@ConfigurationProperties` and Jackson beans may need setters — `record` does not fit there unless the framework version supports it (Spring Boot 2.6+ binds records; Jackson 2.12+ reads them).
