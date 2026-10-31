function _ai_models_label --description "Set the grouping label of an installed model (general clears it)" --argument-names name label
    # A label says what you keep the model for (e.g. coding) — capabilities can't tell that.
    # Stored per model digest, so every tag of the model shares it (docs/refactoring.md §7a).
    if test -z "$name"; or test -z "$label"
        set_color red
        echo "Error: ai models label NAME LABEL   (LABEL general clears it)"
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

    set label (string lower -- $label)
    if test "$label" = general
        _ai_models_meta_set $digest label ''
        echo "$model → General"
    else
        _ai_models_meta_set $digest name $model
        _ai_models_meta_set $digest label $label
        echo "$model → $label"
    end
end
