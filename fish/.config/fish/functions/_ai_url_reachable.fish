function _ai_url_reachable --description "True if URL answers at all within 2 s (any HTTP status); false on DNS/connect failure" --argument-names url
    # Connectivity only: a 401/404 still means the endpoint is there. Used by runner
    # probes so an unreachable provider fails in seconds, not after the runner's retries.
    set -l code (command curl -s -o /dev/null --connect-timeout 2 -m 4 -w '%{http_code}' $url 2>/dev/null)
    test -n "$code"; and test "$code" != 000
end
