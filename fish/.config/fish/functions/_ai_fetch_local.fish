function _ai_fetch_local --description "Fetch locally installed Ollama models (API or cached)"
    set -l cache ~/.cache/ai-models.json

    # Try the server (local or OLLAMA_HOST)
    set -l response (curl -s --connect-timeout 3 (_ai_ollama_host)/api/tags 2>/dev/null)
    if test -n "$response"; and echo "$response" | jq -e '.models' &>/dev/null
        mkdir -p (dirname $cache)
        echo "$response" >$cache
        return 0
    end

    # Fallback to cache
    if test -f $cache
        return 1
    end

    return 2
end
