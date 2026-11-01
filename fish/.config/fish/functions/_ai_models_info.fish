function _ai_models_info --description "Model details: installed → from the local server; not installed → from the ollama registry manifest"
    if test (count $argv) -lt 1
        set_color red
        echo "Error: specify model — ai models info NAME[:TAG]"
        set_color normal
        return 1
    end
    set -l model (_ai_model_norm $argv[1])

    _ai_fetch_local >/dev/null
    set -l digest (_ai_model_digest $model)
    if test -z "$digest"
        _ai_models_info_remote $model
        return
    end

    _ai_ensure_running; or return 1
    set -l info (curl -s (_ai_ollama_host)/api/show -d (jq -nc --arg n $model '{name: $n, verbose: true}') 2>/dev/null)
    if test -z "$info"; or echo "$info" | jq -e '.error' &>/dev/null
        set_color red
        echo "Error: model '$model' not found"
        set_color normal
        return 1
    end

    set -l family (echo $info | jq -r '.details.family // "" | if . == "" then "unknown" else . end')
    set -l params (echo $info | jq -r '.details.parameter_size // "" | if . == "" then "unknown" else . end')
    set -l quant (echo $info | jq -r '.details.quantization_level // "unknown"')
    set -l format (echo $info | jq -r '.details.format // "unknown"')
    set -l context (echo $info | jq -r '[.model_info // {} | to_entries[] | select(.key | endswith(".context_length")) | .value][0] // "unknown"')
    set -l caps (echo $info | jq -r '.capabilities // [] | join(", ")')
    set -l license (echo $info | jq -r '.license // empty' | head -1)

    set -l cache ~/.cache/ai-models.json
    set -l size_bytes (jq -r --arg d $digest '[.models[] | select(.digest == $d)][0].size' $cache)
    set -l tags (jq -r --arg d $digest '.models[] | select(.digest == $d) | .name' $cache)
    set -l label (_ai_models_meta_get $digest label)
    set -l trial (_ai_models_meta_get $digest trial)

    set_color cyan
    echo "Model: $model"
    set_color normal
    test (count $tags) -gt 1; and printf "  %-16s %s\n" "Tags:" (string join ", " $tags)
    printf "  %-16s %s\n" "Family:" $family
    printf "  %-16s %s\n" "Parameters:" $params
    set -l arch (_ai_model_arch $model $digest)
    printf "  %-16s %s\n" "Type:" (test -n "$arch"; and echo $arch; or echo unknown)
    printf "  %-16s %s\n" "Quantization:" $quant
    printf "  %-16s %s\n" "Format:" $format
    printf "  %-16s %s\n" "Context:" $context
    printf "  %-16s %s\n" "Size:" (math -s1 "$size_bytes / 1073741824")" GB"
    printf "  %-16s %s\n" "Capabilities:" "$caps"
    test -n "$label"; and printf "  %-16s %s\n" "Label:" $label
    test -n "$trial"; and printf "  %-16s %s\n" "Trial:" "since "(_ai_relative_time $trial)" — ai models keep / drop $model"

    if test -n "$license"
        echo
        set_color yellow
        echo "License:"
        set_color normal
        echo "  $license"
    end
end
