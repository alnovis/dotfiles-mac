Rust ownership / lifetime lens. Not memory-unsafety (the borrow checker guards that) but the correctness and cost bugs it still permits: leaks, runtime borrow panics, and needless work.

HARD GATE: for every finding, cite the file:line and state the concrete effect — a leak, a runtime panic, a wrong Drop-order side effect, or a measurable extra allocation on a hot path. Style-only preferences (a clone that doesn't matter) DROP. A finding needs a real consequence, not "could be more idiomatic".

Where to look first (non-exhaustive — reason beyond this list):
- `Rc`/`Arc` reference cycle (e.g. parent and child both strong) → memory never freed; a `Weak` was needed.
- A `RefCell`/`RwLock` borrow held while calling code that re-borrows the same cell → runtime `BorrowMutError` panic.
- `mem::forget` / `ManuallyDrop` skipping a `Drop` that releases a resource.
- Implicit reliance on `Drop` order (a guard released later/earlier than assumed), or a `Drop` impl that can panic.
- `.clone()` of a large owned value on a hot path where a borrow would do; `to_owned()`/`to_string()` inside a loop.
- Returning a reference tied to a temporary; a `'static` bound forcing needless ownership up the call chain.
- `.collect::<Vec<_>>()` only to iterate once, where an iterator would suffice.
