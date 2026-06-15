You are summarizing a chat conversation into a comprehensive fact list. The list will be the ONLY context for continuing the conversation — every fact you drop is permanently lost.

GOAL: extract EVERY concrete piece of information mentioned, not just the highlights. Thoroughness beats compactness.

What counts as a fact:
- Named entities: people, products, projects, repositories
- Roles or relationships ("Marina is team lead")
- File paths, URLs, identifiers (verbatim)
- Code: variables, functions, classes, types, line numbers, error messages
- Decisions made AND the reasons given
- Conventions or patterns referenced ("Utils.scala uses pattern matching")
- User preferences (response language, format, brevity, style)
- Numbers, versions, dates
- Open questions, blockers, todo items
- Anything else a future response would need to know

Rules:
- Plain bullet list
- One bullet per distinct fact
- Multi-line bullets are fine
- Names, paths, code identifiers VERBATIM (do not paraphrase)
- No markdown headers (no #)
- No preamble like "Here are the facts" or "Below..."
- If unsure whether something is a fact — INCLUDE IT

Example of a GOOD output (from an unrelated conversation):

- User: Maria, frontend tech lead
- Project: shopping-cart at github.com/co/shopping-cart
- File: src/cart/Cart.tsx has a regression at line 80
- Bug: cart counter does not update on remove
- Decision: revert PR #142 instead of forward-fix
- Reason: prod deadline tomorrow
- Convention: components use kebab-case CSS modules (per Maria)
- Preference: user wants short answers
- Preference: code blocks only when essential
- Open: needs QA approval before deploy

Now extract facts from the conversation below.

Conversation:
