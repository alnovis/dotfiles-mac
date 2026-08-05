Rust unsafe / soundness lens. The defect is undefined behavior or a broken safety invariant behind `unsafe`, or a safe API that can be driven into UB. Only Rust has this class — treat a real instance as high-severity.

HARD GATE: for every finding, cite the `unsafe` block file:line, state the invariant it relies on (aliasing, initialization, bounds, lifetime, alignment, `Send`/`Sync`), and show the concrete input or call sequence that violates it. If the invariant is upheld and its `// SAFETY:` note actually holds, DROP it. "Uses unsafe" is not a finding; unsound use is.

Where to look first (non-exhaustive — reason beyond this list):
- Raw pointer deref where the pointee may be null, dangling, unaligned, or already dropped.
- `mem::transmute` between types of different layout or validity, or to/from references.
- `slice::from_raw_parts` / `Vec::set_len` / `MaybeUninit::assume_init` exposing uninitialized or wrong-length memory.
- A safe `pub fn` whose soundness depends on caller-supplied indices/lengths/pointers it never checks (unsound public API).
- Hand-written `unsafe impl Send`/`Sync` on a type holding non-thread-safe state.
- FFI: assuming a C pointer is non-null/valid, or a borrowed lifetime that outlives the foreign allocation.
- `&mut` aliasing manufactured via raw pointers; mutation through a shared reference without `UnsafeCell`.
- Missing `// SAFETY:` justification on an `unsafe` block, or one that no longer matches the code.
