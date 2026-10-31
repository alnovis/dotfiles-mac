function _ai_models_meta_get --description "Read FIELD of the user metadata of model DIGEST (label, trial, name)" --argument-names digest field
    # ~/.config/ai/models.json: {"<digest>": {"name": …, "label": …, "trial": …}}. Keyed by
    # digest, so every tag of one model shares one record (docs/refactoring.md §7a).
    set -l f ~/.config/ai/models.json
    test -f $f; or return 1
    jq -r --arg d $digest --arg k $field '.[$d][$k] // empty' $f 2>/dev/null
end
