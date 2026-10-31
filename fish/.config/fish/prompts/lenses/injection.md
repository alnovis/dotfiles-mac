Injection lens. Attacker-controlled input merged into a downstream interpreter — SQL, shell, LDAP, XPath, XML parser, template engine, regex, file path, header or redirect — without separating code from data.

HARD GATE: a finding needs ALL THREE — (a) a SINK that interprets its input, (b) a SOURCE an external actor reaches (request field, message body, upload, CLI arg, or a DB row an untrusted party wrote earlier — second-order), and (c) NO defence between them: no parameter binding, no allow-list, no context-correct escaper. A literal or fixed-enum argument at the sink, or no path from a source on any branch: DROP. "Input is not validated" with no sink is not a finding. Each distinct sink is its own finding with its own class — three string-built queries are three findings, not one "input validation missing".

Where to look first (non-exhaustive — reason beyond this list):
- SQL built by concatenation or interpolation: `"SELECT ... " + id`, Scala `s"..."` passed to a raw query, MyBatis `${}` (not `#{}`), Slick `sql"""#$x"""`, `createNativeQuery(str)`, ClickHouse/JDBC `Statement.execute(str)`.
- OS command: `Runtime.exec`/`ProcessBuilder` with a shell (`sh -c`) and interpolated args; Rust `Command::new("sh").arg("-c")`.
- XXE: `DocumentBuilderFactory`/`SAXParserFactory`/`XMLInputFactory` without `disallow-doctype-decl` or secure processing — the factory is a candidate, the missing flag is the finding.
- Path traversal / Zip-Slip: a file path or archive entry name from input joined to a base dir with no normalize-then-prefix check.
- Parse-check-use mismatch: input parsed to check host or prefix, then the raw string is used.
- CRLF / log forging: request values written into response headers or log lines with `\r\n` intact.
- ReDoS: a pattern with nested quantifiers compiled from or run against unbounded input (length-capped input: low).
- Defence in the wrong context: HTML-escaping a value bound for JS or a URL; an allow-list checked on a different variable than the one reaching the sink.
