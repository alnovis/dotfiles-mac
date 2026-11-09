function _ai_models_rm --description "Remove one installed tag (ai models drop removes the whole model)"
    if test (count $argv) -lt 1
        set_color red
        echo "Error: specify model — ai models rm MODEL"
        set_color normal
        return 1
    end

    _ai_ensure_running; or return 1

    set -l model (_ai_model_norm $argv[1])
    _ai_fetch_local >/dev/null
    set -l digest (_ai_model_digest $model)
    if test -z "$digest"
        set_color red
        echo "Error: model '$model' is not installed"
        set_color normal
        return 1
    end

    read -l -P "Remove $model? (y/N) " confirm
    if test "$confirm" != y -a "$confirm" != Y
        echo "Aborted"
        return 1
    end

    ollama rm $model; or return 1
    _ai_fetch_local >/dev/null
    # The runners still list it otherwise, and would offer a model that is gone
    _ai_models_unregister $model

    # Last tag of the model gone → its label/trial go too
    if not jq -e --arg d $digest 'any(.models[]; .digest == $d)' ~/.cache/ai-models.json >/dev/null 2>&1
        for field in label trial name
            _ai_models_meta_set $digest $field ''
        end
    end

    set -l dm (_ai_default_model "" ollama)
    if test -n "$dm"; and test (_ai_model_norm $dm) = $model
        set_color yellow
        echo "Note: $model was the default model — set another: ai models use MODEL"
        set_color normal
    end

    echo "---"
    set_color green
    echo "Removed: $model"
    set_color normal
end
