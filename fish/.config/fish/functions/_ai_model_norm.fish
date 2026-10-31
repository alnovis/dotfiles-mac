function _ai_model_norm --description "Canonical ollama model name: NAME without a tag means NAME:latest" --argument-names name
    # One rule for every comparison (tasks, default model, labels, use): a config value
    # `north-mini-code-1.0` and the installed `north-mini-code-1.0:latest` are the same model.
    test -n "$name"; or return 1
    if string match -q '*:*' -- $name
        echo $name
    else
        echo "$name:latest"
    end
end
