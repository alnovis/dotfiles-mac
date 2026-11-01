Fish shell lens. Fish is not bash: it has no word splitting, its own status and scoping rules, and lists everywhere. Most models read it as bash — so this lens is as much about what NOT to report as what to report.

HARD GATE: for every finding, name the concrete input or state (an empty list, a multi-line command output, a value with a tab, a flag the caller passes) and what the function then does wrong. Before reporting, check the "Not bugs" list below: a finding that rests on bash semantics (word splitting, `$?`, `fi`/`done`, `[[ ]]`) is wrong in fish — DROP it.

Where to look first (non-exhaustive — reason beyond this list):
- `set x (cmd)` splits the output into one element per LINE: multi-line text (a prompt, a diff, JSON) needs `(cmd | string collect)`, or it is silently turned into a list and later joined with spaces.
- Empty lists vanish: `test -n $var` with an empty `$var` becomes `test -n` and is TRUE; a list of two makes `test` fail with too many arguments — quote it (`test -n "$var"`). unquoted `foo$empty` expands to nothing at all (not to `foo`), and `$a$b` with lists is a cartesian product.
- Escapes in double quotes: `"\t"`, `"\n"` are a literal backslash and letter — only unquoted `\t` or `printf` produce the character.
- Scope: `set -l x` inside `if`/`for`/`begin` is local to that BLOCK — gone after `end`; `set -U` in a function writes a universal variable that persists across sessions and can shadow or be shadowed by a global.
- `string match`/`string replace` without `-q` print to stdout — inside `if` they pollute the output, inside `(…)` they become part of the value; `string replace -f` drops lines that did not match.
- `eval $cmd $argv` without `(string escape -- $argv)` re-parses user arguments; `argparse ... -- $argv` with no `; or return` keeps running after a bad flag.
- `$status` is overwritten by every command — read it immediately; after a pipeline it is the LAST command's, `$pipestatus` holds all of them.
- `math` returns floats (`math 10 / 3` → 3.333333) where an integer was assumed — use `math -s0` or `round`.
- Autoloading: a helper defined inside another function's file exists only after that file was loaded; a function file whose name differs from the function never autoloads.

Not bugs in fish (bash habits that misfire here):
- `cmd; or other`, `cmd; and other`, `and`/`or`/`not` at the start of a line — the normal way to chain on status.
- `set -l n (cmd); or continue` — `set` keeps the status of the command substitution.
- Unquoted `$var` holding spaces — no word splitting; it is passed as one argument per list element.
- `(cmd)` and `$(cmd)` (fish ≥ 3.4) are both command substitution; `$status`, not `$?`; `end`, not `fi`/`done`; `test`, not `[[ ]]`.
- `$argv[2..]` on a short list is an empty slice, not an error; `set -q var` tests existence, `set -q var[1]` non-emptiness.
- A variable exported with `set -lx`/`set -x` is visible in functions the caller invokes.
