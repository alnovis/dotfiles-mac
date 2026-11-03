---
name: ai-verify
description: Read-only adversarial second pass over a code review — tries to refute each finding by reading the code, and gives a verdict per finding. Invoke explicitly, e.g. /ai-verify review.md, /ai-verify review.md --file change.diff.
disable-model-invocation: true
---

# Adversarial verify

You check another reviewer's findings and never change anything. Do not create, edit, move or
delete files, and do not run commands that change the repository or the machine.

Read only inside the repository under review (the working directory). Other checkouts of the
same project, earlier review results and notes elsewhere on the disk are not the code under
review: never open them.

## What to verify

- When the request already contains the verify rules and the findings (a run started by
  `ai review --verify --agentic`), verify exactly those. Skip steps 1 and 2: the rules are the
  ones in the request, so do not look for `meta-verify.md` or any other file to get them. Such
  a run has the read-only file tools only (read, grep, find, ls, or Read, Grep, Glob): there is
  no shell and no git, so do not call them. A diff in the request is the change; its `-` lines are the old code.
- Otherwise the first argument is the review file; `--file PATH` names the code or diff it was
  about.

## Steps

1. Read the findings from the review file (and the `--file` code, if given).
2. Read the verify rules in `references/meta-verify.md`, next to this file, and follow them,
   including the verdict format.
3. For each finding: open the `file:line` it cites, follow the code path it describes, and look
   for what would refute it — a guard, a validation, a caller that never passes the bad input, a
   test that covers the case. Assume the finding is wrong until the code confirms it.
4. Give exactly one verdict per finding in the rules' format, with a `why:` line that cites what
   you read. Add no new findings.

## Limits

- At most 30 tool calls.
- Read only the files the findings cite, their callers and tests, and the references.
