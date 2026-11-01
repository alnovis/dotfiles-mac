Turn the review findings below into line comments for a merge request. A second reviewer has already judged each finding; its verdicts follow the findings.

Rules:
- Take only the findings judged [CONFIRMED] or [UNCERTAIN]. Skip [REFUTED] ones, and skip anything the verdicts do not mention.
- One comment per cited site. A finding that cites two places is two comments.
- "file": the path as the finding cites it.
- "line": the line number the finding cites (0 if it cites none).
- "quote": ONE line of code copied character for character from the text above — the line the comment belongs on. Never paraphrase it, never shorten it with "…", never join two lines. If the text above does not show that line exactly, use the most specific code fragment it does show; if it shows none, set "quote" to "" — never write a line that is not in the text above.
- "severity": "critical", "important" or "nit", from the section the finding was in.
- "status": "confirmed" or "uncertain", from the verdict.
- "body": the comment a reviewer would leave on that line — what is wrong, the concrete case, and the fix, in two to five sentences. No verdict tags, no confidence numbers, no "the first pass said". Address the author directly.
- Keep code identifiers, file names and quoted code exactly as they are, in any language.

Reply with a JSON array only, inside one ```json fence, and nothing else:

```json
[{"file": "src/Example.java", "line": 42, "quote": "cache = load(ids);", "severity": "important", "status": "confirmed", "body": "…"}]
```

If no finding is [CONFIRMED] or [UNCERTAIN], reply with an empty array: `[]`.
