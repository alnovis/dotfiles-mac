SSRF lens. Server-side request forgery — the application becomes the attacker's HTTP client, inside the perimeter and holding its service credentials.

HARD GATE: a finding needs ALL THREE — (a) a SINK that does network I/O to a URL, host or port, or a helper whose contract is to fetch one (a `url`/`uri`/`endpoint`/`callback` parameter, a `download`/`fetch`/`import*` name) even when its body is unseen; (b) a SOURCE — the URL, host, port or scheme comes from a request, a webhook registration, an uploaded document, or a DB column an untrusted party wrote; (c) NO allow-list of BOTH scheme and host enforced on the address actually connected to. A literal URL, a fixed base where input fills only the path or query, or a URL set only by deployment config: DROP. Syntax checks (`new URL(s)`, `URI.create`, `^https?://`) and a host check on the unresolved string are NOT defences. One finding per route that reaches the sink.

Where to look first (non-exhaustive — reason beyond this list):
- Outbound clients fed from request data: `HttpClient`, OkHttp, `WebClient`, sttp, Akka/Pekko HTTP, `reqwest`, `java.net.URL.openStream`.
- Features that fetch by design: avatar-by-URL, webhooks and "test connection", link preview, import-from-URL, render-to-PDF/thumbnail, OAuth `jwks_uri` / OIDC discovery.
- Redirects followed by default after the host check — each hop must be re-checked, or redirects disabled.
- DNS rebinding: the host resolved once for the check and again for the connect.
- Deny-lists of private literals instead of resolve-then-reject: misses `169.254.169.254`, IPv6 `::ffff:` forms, decimal/octal IPs, internal DNS names.
- Blind SSRF still counts: status code, timing or error text lets the attacker map internal ports — say which channel leaks.
- Indirect fetchers: XXE external entities, image/PDF libraries resolving remote references, JDBC URLs built from input.
