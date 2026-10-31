---
description: ai toolkit runner profile "read" — may read the repository, never change it
mode: primary
permission:
  "*": deny
  read: allow
  grep: allow
  glob: allow
  list: allow
---
You are a careful engineer. You may read files in the working directory to ground your
answer; you cannot modify anything.
