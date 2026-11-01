function _ai_agent_pi_endpoint --description "pi's config for PROVIDER [MODEL]: baseUrl, api, apiKey reference, contextWindow, maxTokens — one per line, empty if unknown" --argument-names provider model
    # The native OpenAI driver reads the endpoint from the runner's config — the toolkit
    # keeps no provider registry of its own, so hosts and keys never enter this repo.
    # Fails when pi has no such provider (its built-in ones have no entry here).
    set -l cfg ~/.pi/agent/models.json
    test -f $cfg; or return 1
    # A model may carry the provider prefix (litellm/selectel/…); pi's list holds the bare id
    set model (string replace -r -- '^'(string escape --style=regex -- $provider)'/' '' "$model")
    set -l ep (jq -r --arg p $provider --arg m "$model" '.providers[$p] // empty
        | ((.models // []) | map(select(.id == $m)) | .[0] // {}) as $mod
        | .baseUrl // "", .api // "", .apiKey // "",
          ($mod.contextWindow // "" | tostring), ($mod.maxTokens // "" | tostring)' $cfg 2>/dev/null)
    test (count $ep) -eq 5; or return 1
    printf '%s\n' $ep
end
