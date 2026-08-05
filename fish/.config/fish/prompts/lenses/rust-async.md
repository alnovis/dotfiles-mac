Rust async lens. Tokio / async-runtime footguns: the defect is stalling the executor, corrupting shared state across an `.await`, or losing a task — invisible until concurrency or load.

HARD GATE: for every finding, cite the file:line and name the concrete consequence — a blocked executor thread, a lock held across `.await` (deadlock / starvation), a dropped task, or work lost on cancellation. If the blocking call runs on `spawn_blocking` or a dedicated pool by design, DROP it. "Is async" is not a defect; a stalled or unsound future is.

Where to look first (non-exhaustive — reason beyond this list):
- `std::sync::Mutex`/`RwLock` guard held across an `.await` point → deadlock or starvation (use `tokio::sync`, or drop the guard before awaiting).
- Blocking IO, `std::thread::sleep`, or a CPU-bound loop inside an `async fn` on the runtime → starves other tasks (needs `spawn_blocking`).
- `tokio::spawn` whose `JoinHandle` is dropped → the task's result and any panic are silently lost.
- A future built but never `.await`ed or spawned — the work never runs.
- Cancellation unsafety: state left half-updated when a future is dropped at an `.await` (no cleanup on cancel).
- `block_on` called from within an async context or a runtime thread.
- `select!` branch that drops an in-flight future with side effects; a busy-poll loop that never yields.
- `Rc`/`RefCell` or a non-`Send` value held across an `.await` or moved between tasks.
