function _ai_agent_pi_probe --description "Reachability of a pi provider: 0 ok, 1 unreachable, 2 can't tell" --argument-names provider
    # The URL lives in pi's own config; providers pi ships built in have none there.
    set -l url (jq -r --arg p "$provider" '.providers[$p].baseUrl // empty' ~/.pi/agent/models.json 2>/dev/null)
    test -n "$url"; or return 2
    _ai_url_reachable $url; or return 1
end
