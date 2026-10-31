function _ai_model_digest --description "Digest of installed model NAME (from the installed-model cache); empty if not installed" --argument-names name
    set -l cache ~/.cache/ai-models.json
    test -f $cache; or return 1
    set -l d (jq -r --arg n (_ai_model_norm $name) '.models[] | select(.name == $n) | .digest' $cache 2>/dev/null)[1]
    test -n "$d"; or return 1
    echo $d
end
