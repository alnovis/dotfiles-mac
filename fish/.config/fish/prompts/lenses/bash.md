Bash / POSIX sh lens. Scripts that work on the author's input and break on a filename with a space, an empty variable, a failed command in the middle, or a different `/bin/sh`.

HARD GATE: for every finding, name the concrete input or state that triggers it (a path with a space, an unset variable, a command that fails mid-pipeline) and what the script then does (deletes the wrong tree, continues after a failure, writes to the wrong place). A shellcheck code by itself is not a finding. If the value provably cannot contain spaces, globs or be empty (`$#`, `$?`, a numeric counter, a fixed literal), DROP the quoting finding.

Where to look first (non-exhaustive — reason beyond this list):
- Unquoted expansions: `$var`, `$(cmd)`, `$@` split on IFS and glob-expand; `for f in $(ls)` / `for f in $(find ...)`; `"$*"` where `"$@"` was meant.
- Empty or unset variables in destructive paths: `rm -rf "$DIR/"`, `cd "$X" && rm *` — no `${VAR:?}` guard, no `set -u`.
- `set -e` that does not fire: inside `if`/`while` conditions, `&&`/`||` chains, functions called from a condition; `local x=$(cmd)` and `export x=$(cmd)` mask the status; no `set -o pipefail`, so `cmd | tee log` hides the failure.
- `cd dir` with no `|| exit`; `exit` inside `$( )` or a `| while` loop leaves only the subshell, and variables set in `cmd | while read` are lost after the loop.
- `read` without `-r` (backslashes eaten) and without `IFS=` (leading/trailing whitespace stripped).
- Temp files with fixed names in `/tmp` instead of `mktemp`, no `trap '...' EXIT` cleanup; `eval` or `sh -c "$input"` on data.
- Bashisms under `#!/bin/sh` (`[[ ]]`, arrays, `==` in `[ ]`, `function f`, `$'..'`, `echo -e`) — breaks where sh is dash or busybox.
- Globs with no match stay literal (no `nullglob`); arithmetic on zero-padded input (`$((08))` is an octal error).
- Not bugs: `[[ $x == y ]]` without quotes on the left (no splitting inside `[[ ]]`); variables without `$` inside `$(( ))`; `local` in bash functions; `: "${VAR:?message}"` as a guard.
