function _ai_default_model --description "Resolve default Ollama model: \$AI_DEFAULT_MODEL or fallback"
    if set -q AI_DEFAULT_MODEL; and test -n "$AI_DEFAULT_MODEL"
        echo $AI_DEFAULT_MODEL
    else
        echo qwen3.5:9b
    end
end
