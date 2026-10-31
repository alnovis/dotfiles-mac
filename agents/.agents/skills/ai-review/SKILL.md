---
name: ai-review
description: Read-only agentic code review of a git change or a file/directory — explores the repository to ground every finding. Invoke explicitly, e.g. /ai-review, /ai-review main, /ai-review --last 2, /ai-review src/Foo.scala --lens crypto.
disable-model-invocation: true
---

# Agentic code review

You review code and never change anything. Do not create, edit, move or delete files. Do not run
commands that change the repository or the machine: no git commit, checkout, reset, stash, push,
no package installs. Reading files and running read-only git commands is fine.

## What to review

- When the request already contains review rules and a diff or a target file (a run started by
  `ai review --agentic`), review exactly that, under those rules. Skip steps 1 and 2.
- Otherwise the arguments say what to review: a base branch (`main`), `--last N`, `--commit SHA`,
  or a PATH (file or directory). With no argument: the current branch against its base branch
  (the first of develop, main, master that exists).

## Steps

1. Get the change. For a branch: `git diff <base>...HEAD`; for `--last N`: `git diff HEAD~N..HEAD`;
   for `--commit SHA`: `git show SHA`; for a PATH: read it. Do not state any git fact (branch,
   base, commit) that you did not read with a git command in this run.
2. Read the review rules: `references/meta-review-diff.md` for a git change,
   `references/meta-review.md` for a file or directory. Follow them, including their output format.
3. Lenses. If the request names lenses (`--lens crypto,access-control`, or the bare names), read
   `references/lenses/<name>.md` for each and apply it on top of the rules. A name with no such
   file: say so and list the available lenses (the `.md` files in `references/lenses/`, except
   README.md). No lens named: apply none.
4. Ground the review in the code. For each changed file read the whole file, not only the hunks.
   For each changed function find its callers (grep) and its tests. Before reporting a suspected
   issue, look for a guard, validation or handler that already covers it.
5. Write the review in the format the rules define. Every finding cites a `file:line` you read
   in this run.

## Limits

- At most 30 tool calls.
- Start from the change: read the changed files, their callers and tests, and the references.
  Do not scan the whole repository.
