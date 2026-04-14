function _ai_get_installed_names --description "Get list of installed Ollama model names"
    set -l cache ~/.cache/ai-models.json

    if test -f $cache
        cat $cache | jq -r '.models[].name' 2>/dev/null
    end
end
