function _ai_models_keep --description "End a trial and keep the model" --argument-names name
    if test -z "$name"
        set_color red
        echo "Error: specify model — ai models keep NAME"
        set_color normal
        return 1
    end
    set -l model (_ai_model_norm $name)
    _ai_fetch_local >/dev/null
    set -l digest (_ai_model_digest $model)
    if test -z "$digest"
        echo "Error: $model is not installed" >&2
        return 1
    end
    if test -z "$(_ai_models_meta_get $digest trial)"
        echo "$model is not on trial — nothing to do"
        return 0
    end
    _ai_models_meta_set $digest trial ''
    set_color green
    echo "Kept: $model"
    set_color normal
end
