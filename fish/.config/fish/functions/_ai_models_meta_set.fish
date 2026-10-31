function _ai_models_meta_set --description "Set FIELD of model DIGEST's metadata to VALUE; empty VALUE removes the field" --argument-names digest field value
    # A record left with nothing but its readable `name` is dropped entirely.
    set -l f ~/.config/ai/models.json
    mkdir -p (dirname $f)
    test -f $f; or echo '{}' >$f
    set -l tmp (mktemp)
    jq --arg d $digest --arg k $field --arg v "$value" '
        if $v == "" then
            (if .[$d] then .[$d] |= del(.[$k]) else . end)
            | with_entries(select((.value | keys - ["name"]) | length > 0))
        else .[$d][$k] = $v end' $f >$tmp
    and mv $tmp $f
    or begin
        rm -f $tmp
        return 1
    end
end
