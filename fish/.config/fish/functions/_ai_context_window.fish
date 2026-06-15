function _ai_context_window --description "Get context window size for ollama MODEL; cache in ~/.cache/ai-context-windows.json" --argument-names model
    set -l cache ~/.cache/ai-context-windows.json

    # Try cache
    if test -f $cache
        set -l v (jq -r --arg m "$model" '.[$m] // empty' $cache 2>/dev/null)
        if test -n "$v"; and test "$v" != null
            echo $v
            return
        end
    end

    # Query ollama; pipe directly so multi-line response stays a single JSON
    set -l body (jq -nc --arg m "$model" '{name: $m}')
    set -l ctx (curl -s -X POST http://localhost:11434/api/show \
        -H 'Content-Type: application/json' -d "$body" 2>/dev/null \
        | jq -r '[.model_info | to_entries[]? | select(.key | endswith("context_length")) | .value] | .[0] // empty' 2>/dev/null)

    if test -z "$ctx"; or test "$ctx" = null
        set ctx 8192
    end

    # Update cache
    mkdir -p (dirname $cache)
    if test -f $cache
        set -l tmp (mktemp)
        jq --arg m "$model" --argjson v $ctx '. + {($m): $v}' $cache >$tmp 2>/dev/null; and mv $tmp $cache; or rm -f $tmp
    else
        jq -nc --arg m "$model" --argjson v $ctx '{($m): $v}' >$cache
    end

    echo $ctx
end
