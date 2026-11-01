function _ai_models_info_remote --description "Details of a not-installed model from its ollama registry manifest (no download)" --argument-names model
    # ollama.com has no search/catalog API and the registry no tag list (both 404); a known
    # NAME:TAG's manifest and blobs are fetchable — the path `ollama pull` uses. See
    # docs/refactoring.md §7a for what is (and is not) available this way.
    set -l ram_fit_ratio 0.7   # weights up to 70% of RAM leave room for the context (KV cache)

    set -l repo (string split -m1 : -- $model)[1]
    set -l tag (string split -m1 : -- $model)[2]
    string match -q '*/*' -- $repo; or set repo library/$repo
    set -l base https://registry.ollama.ai/v2/$repo

    # --retry: the registry/CDN drops the odd request; a blip must not read as "not found"
    set -l get curl -sfL --retry 2 --retry-delay 1 --connect-timeout 5 -m 20
    set -l manifest ($get -H 'Accept: application/vnd.docker.distribution.manifest.v2+json' $base/manifests/$tag 2>/dev/null | string collect)
    if test -z "$manifest"
        set_color red
        echo "Error: '$model' is not installed and not found in the ollama registry (check the tag on https://ollama.com/library)" >&2
        set_color normal
        return 1
    end

    set -l size_bytes (echo $manifest | jq '[.layers[].size] | add')
    set -l vision (echo $manifest | jq -r 'if any(.layers[]; .mediaType | endswith(".projector")) then "yes" else "no" end')
    set -l draft (echo $manifest | jq -r 'if any(.layers[]; .mediaType | endswith(".draft")) then "yes (speculative decoding)" else empty end')
    set -l config ($get $base/blobs/(echo $manifest | jq -r '.config.digest') 2>/dev/null | string collect)
    test -n "$config"; or set config '{}'
    set -l params (echo $config | jq -r '.model_type // "unknown"')
    set -l quant (echo $config | jq -r '.file_type // "unknown"')
    set -l family (echo $config | jq -r '.model_family // "unknown"')
    set -l requires (echo $config | jq -r '.requires // empty')
    set -l parser (echo $config | jq -r '.parser // empty')
    set -l arch (_ai_models_info_remote_arch $base "$manifest")
    test -n "$arch"; or set arch unknown

    # tools / thinking: only old-style Go templates say it; parser-based models decide in ollama
    set -l abilities
    set -l tpl_digest (echo $manifest | jq -r '[.layers[] | select(.mediaType | endswith(".template"))][0].digest // empty')
    if test -n "$tpl_digest"
        set -l tpl ($get $base/blobs/$tpl_digest 2>/dev/null | string collect)
        string match -q '*.Tools*' -- $tpl; and set -a abilities tools
        string match -qr '\.(Think|IsThinkSet)\b' -- $tpl; and set -a abilities thinking
    end
    set -l abilities_str (string join ", " $abilities)
    if test -z "$abilities_str"
        if test -n "$parser"
            set abilities_str "decided by ollama after install (parser $parser)"
        else
            set abilities_str "none declared"
        end
    end

    set -l ram_bytes (sysctl -n hw.memsize 2>/dev/null; or echo 0)
    set -l size_gb (math -s1 "$size_bytes / 1073741824")
    set -l ram_gb (math -s0 "$ram_bytes / 1073741824")
    set -l fit "fits"
    if test $size_bytes -gt $ram_bytes
        set fit "won't fit"
    else if test $size_bytes -gt (math -s0 "$ram_bytes * $ram_fit_ratio")
        set fit "tight — little room for context"
    end

    set -l local_ver (ollama --version 2>/dev/null | string match -r '[0-9]+\.[0-9]+\.[0-9]+')[1]
    set -l req_str "—"
    if test -n "$requires"
        set req_str $requires
        if test -n "$local_ver"
            if test (printf '%s\n' $requires $local_ver | sort -V | head -1) = $requires
                set req_str "$requires (you have $local_ver)"
            else
                set req_str "$requires — NEWER than your $local_ver, update ollama first"
            end
        end
    end

    set_color cyan
    echo "Model: $model (not installed — from the ollama registry)"
    set_color normal
    printf "  %-16s %s\n" "Download:" "$size_gb GB · RAM $ram_gb GB → $fit"
    printf "  %-16s %s\n" "Family:" $family
    printf "  %-16s %s\n" "Parameters:" $params
    printf "  %-16s %s\n" "Type:" $arch
    printf "  %-16s %s\n" "Quantization:" $quant
    printf "  %-16s %s\n" "Vision:" $vision
    printf "  %-16s %s\n" "Tools/thinking:" $abilities_str
    test -n "$draft"; and printf "  %-16s %s\n" "Draft model:" $draft
    printf "  %-16s %s\n" "Needs ollama:" $req_str
    echo
    echo "  Try it: ai models try $model"
end

function _ai_models_info_remote_gguf_uint --description "Integer value of the GGUF key *.KEY in a header file, or nothing" --argument-names file key
    # The key name is stored as plain bytes; right after it come the value type and the value
    set -l hit (LC_ALL=C grep -a -b -o "[a-z0-9_]*\.$key" $file | head -1)
    test -n "$hit"; or return 1
    set -l parts (string split -m1 : -- $hit)
    set -l off (math $parts[1] + (string length -- $parts[2]))
    # macOS od ends with an empty line after the number — keep only the number
    set -l type (od -An -tu4 -j $off -N4 $file | string trim | string match -r '\d+')
    switch "$type"
        case 4 # uint32
            od -An -tu4 -j (math $off + 4) -N4 $file | string trim | string match -r '\d+'
        case 10 # uint64
            od -An -tu8 -j (math $off + 4) -N8 $file | string trim | string match -r '\d+'
    end
end

function _ai_models_info_remote_arch --description "MoE or dense from the registry, without downloading the model" --argument-names base manifest
    set -l get curl -sfL --retry 2 --retry-delay 1 --connect-timeout 5 -m 20

    # GGUF: the architecture keys sit at the start of the file, before the tokenizer, so the
    # first 256 KB are enough. Each key is followed by a uint32 value type and the value.
    set -l model_digest (echo $manifest | jq -r '[.layers[] | select(.mediaType == "application/vnd.ollama.image.model")][0].digest // empty')
    if test -n "$model_digest"
        set -l hdr (mktemp)
        # A short read (the CDN drops slow transfers) would cut the header before the expert
        # keys and pass for dense — accept only the full range
        if not $get -r 0-262143 $base/blobs/$model_digest -o $hdr 2>/dev/null
            or test (wc -c <$hdr | string trim) -ne 262144
            rm -f $hdr
            return 1
        end
        set -l total (_ai_models_info_remote_gguf_uint $hdr expert_count)
        set -l used (_ai_models_info_remote_gguf_uint $hdr expert_used_count)
        test -n "$used"; or set used "?"
        set -l ffn (LC_ALL=C grep -a -c '\.feed_forward_length' $hdr)
        rm -f $hdr
        if test -n "$total"; and test "$total" -gt 0
            echo "MoE $used/$total"
        else if test "$ffn" -gt 0
            echo dense
        end
        return 0
    end

    # safetensors (MLX): the original config.json is one of the small json layers
    for d in (echo $manifest | jq -r '.layers[] | select(.mediaType == "application/vnd.ollama.image.json" and .size < 200000) | .digest')
        set -l arch ($get $base/blobs/$d 2>/dev/null | jq -r 'select(.architectures)
            | (.text_config // .) as $c
            | if ($c.num_experts // 0) > 0 then "MoE \($c.num_experts_per_tok // "?")/\($c.num_experts)"
              elif $c.intermediate_size then "dense"
              else empty end' 2>/dev/null)
        if test -n "$arch"
            echo $arch
            return 0
        end
    end
end
