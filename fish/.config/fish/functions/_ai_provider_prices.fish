function _ai_provider_prices --description "Prices of PROVIDER's models per 1M tokens, as model<TAB>input<TAB>output lines (a litellm gateway's /model/info, cached for a day)" --argument-names provider
    # Only a litellm gateway answers /model/info; anything else (or off the VPN) gives
    # nothing, and a stale cache is better than no prices. The gateway knows prices only —
    # no context, no capabilities — so this is all a listing can take from it.
    set -l cache ~/.cache/ai/prices-$provider.json
    set -l max_age 86400

    set -l fresh 0
    if test -f $cache
        set -l age (math (date +%s) - (stat -f %m $cache))
        test $age -lt $max_age; and set fresh 1
    end

    if test $fresh -eq 0
        set -l runner (_ai_default_agent 2>/dev/null)
        set -l ep
        test -n "$runner"; and functions -q _ai_agent_{$runner}_endpoint
        and set ep (_ai_agent_{$runner}_endpoint $provider "")
        if test "$ep[2]" = openai-completions
            set -l url (string replace -r '/v1/?$' '' -- $ep[1])/model/info
            set -l key (_ai_endpoint_key $ep[3])
            set -l hdr (mktemp)
            set -l tmp (mktemp)
            chmod 600 $hdr
            test -n "$key"; and printf 'Authorization: Bearer %s\n' $key >$hdr
            # Short timeouts: a listing must not hang when the gateway is out of reach
            if curl -sf --connect-timeout 2 -m 5 -H @$hdr $url -o $tmp 2>/dev/null
                and jq -e '.data | type == "array"' $tmp >/dev/null 2>&1
                mkdir -p (dirname $cache)
                mv $tmp $cache
            end
            rm -f $hdr $tmp
        end
    end

    test -f $cache; or return 1
    jq -r '.data[] | select(.litellm_params.input_cost_per_token != null)
        | [.model_name,
           (.litellm_params.input_cost_per_token * 1e6 | . * 100 | round / 100 | tostring),
           ((.litellm_params.output_cost_per_token // 0) * 1e6 | . * 100 | round / 100 | tostring)]
        | @tsv' $cache 2>/dev/null
end
