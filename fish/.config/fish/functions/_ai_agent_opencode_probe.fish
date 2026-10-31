function _ai_agent_opencode_probe --description "Reachability of an opencode provider: 0 ok, 1 unreachable, 2 can't tell" --argument-names provider
    # The URL lives in opencode's own config; its built-in providers have none there.
    set -l url
    for f in ~/.config/opencode/opencode.json ~/.config/opencode/config.json
        test -f $f; or continue
        set url (jq -r --arg p "$provider" '.provider[$p].options.baseURL // empty' $f 2>/dev/null)
        test -n "$url"; and break
    end
    test -n "$url"; or return 2
    _ai_url_reachable $url; or return 1
end
