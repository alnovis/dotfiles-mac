function _ai_agent_opencode_endpoint --description "opencode's config for PROVIDER [MODEL]: baseUrl, api, apiKey reference, contextWindow, maxTokens, reasoning — one per line, empty if unknown" --argument-names provider model
    # Same contract as _ai_agent_pi_endpoint. opencode names the API by its npm package:
    # @ai-sdk/openai-compatible is the OpenAI chat-completions API.
    set model (string replace -r -- '^'(string escape --style=regex -- $provider)'/' '' "$model")
    for f in ~/.config/opencode/opencode.json ~/.config/opencode/config.json
        test -f $f; or continue
        set -l ep (jq -r --arg p $provider --arg m "$model" '.provider[$p] // empty
            | (.models[$m] // {}) as $mod
            | .options.baseURL // "",
              (if (.npm // "") | test("openai-compatible") then "openai-completions" else .npm // "" end),
              .options.apiKey // "",
              ($mod.limit.context // "" | tostring), ($mod.limit.output // "" | tostring),
              ($mod.reasoning // "" | tostring)' $f 2>/dev/null)
        if test (count $ep) -eq 6
            printf '%s\n' $ep
            return 0
        end
    end
    return 1
end
