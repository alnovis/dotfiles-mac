function _ai_model_caps --description "Capabilities of installed model NAME with DIGEST (tools, thinking, vision, …), cached by digest" --argument-names name digest
    # A digest never changes its content, so the cache never goes stale; only the first
    # look at a model asks the server (/api/show). Offline and uncached → nothing.
    set -l cache ~/.cache/ai/model-caps.json
    if test -f $cache
        set -l c (jq -r --arg d $digest '.[$d] // empty | join(" ")' $cache 2>/dev/null)
        if test -n "$c"
            echo $c
            return 0
        end
    end

    set -l caps (curl -s --connect-timeout 2 -m 5 (_ai_ollama_host)/api/show -d (jq -nc --arg n $name '{name: $n}') 2>/dev/null \
        | jq -c '.capabilities // empty' 2>/dev/null)
    test -n "$caps"; or return 1

    mkdir -p (dirname $cache)
    test -f $cache; or echo '{}' >$cache
    set -l tmp (mktemp)
    jq --arg d $digest --argjson c $caps '.[$d] = $c' $cache >$tmp; and mv $tmp $cache; or rm -f $tmp
    echo $caps | jq -r 'join(" ")'
end
