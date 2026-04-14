function _ai_models_info --description "Show detailed Ollama model info"
    if test (count $argv) -lt 1
        set_color red
        echo "Error: specify model — ai models info MODEL"
        set_color normal
        return 1
    end

    _ai_ensure_running; or return 1

    set -l model $argv[1]
    set -l info (curl -s http://localhost:11434/api/show -d "{\"name\": \"$model\", \"verbose\": true}" 2>/dev/null)

    if test -z "$info"; or echo "$info" | jq -e '.error' &>/dev/null
        set_color red
        echo "Error: model '$model' not found"
        set_color normal
        return 1
    end

    set -l default_model (set -q AI_DEFAULT_MODEL; and echo $AI_DEFAULT_MODEL; or echo "")

    # Extract details
    set -l family (echo $info | jq -r '.details.family // "unknown"')
    set -l params (echo $info | jq -r '.details.parameter_size // "unknown"')
    set -l quant (echo $info | jq -r '.details.quantization_level // "unknown"')
    set -l format (echo $info | jq -r '.details.format // "unknown"')
    set -l context (echo $info | jq -r '.model_info["general.context_length"] // .model_info["llama.context_length"] // "unknown"')
    set -l license (echo $info | jq -r '.license // empty' | head -1)
    set -l system (echo $info | jq -r '.system // empty' | head -3)

    # Size from local cache
    set -l local_cache ~/.cache/ai-models.json
    set -l size_str "unknown"
    if test -f $local_cache
        set -l size_bytes (cat $local_cache | jq -r --arg name "$model" '.models[] | select(.name == $name) | .size' 2>/dev/null)
        if test -n "$size_bytes"; and test "$size_bytes" != null
            set size_str (math -s1 "$size_bytes / 1073741824")" GB"
        end
    end

    # Display
    set_color cyan
    echo "Model: $model"
    set_color normal
    if test "$model" = "$default_model"
        set_color yellow
        echo "★ default"
        set_color normal
    end

    echo ""
    printf "  %-16s %s\n" "Family:" $family
    printf "  %-16s %s\n" "Parameters:" $params
    printf "  %-16s %s\n" "Quantization:" $quant
    printf "  %-16s %s\n" "Format:" $format
    printf "  %-16s %s\n" "Context:" $context
    printf "  %-16s %s\n" "Size:" $size_str

    if test -n "$license"
        echo ""
        set_color yellow
        echo "License:"
        set_color normal
        echo "  $license"
    end

    if test -n "$system"
        echo ""
        set_color yellow
        echo "System prompt:"
        set_color normal
        echo "$system" | while read -l line
            echo "  $line"
        end
    end
end
