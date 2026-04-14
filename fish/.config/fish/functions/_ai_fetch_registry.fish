function _ai_fetch_registry --description "Fetch Ollama model registry (remote or cached)"
    set -l cache ~/.cache/ai-registry.json

    # Try remote API
    set -l response (curl -s --connect-timeout 5 https://ollama.com/api/tags 2>/dev/null)
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
