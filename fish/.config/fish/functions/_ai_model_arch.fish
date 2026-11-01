function _ai_model_arch --description "Architecture of installed model NAME with DIGEST: 'MoE USED/TOTAL', 'MoE' or 'dense', cached by digest" --argument-names name digest
    # MoE runs a few experts per token, so it is several times faster than a dense model of
    # the same size on disk — that is what makes this worth a column. Read from /api/show,
    # never guessed from the name. A digest never changes, so the cache never goes stale;
    # offline and uncached → nothing.
    set -l cache ~/.cache/ai/model-arch.json
    if test -f $cache; and jq -e --arg d $digest 'has($d)' $cache >/dev/null 2>&1
        jq -r --arg d $digest '.[$d]' $cache
        return 0
    end

    set -l url (_ai_ollama_host)/api/show
    set -l show (curl -s --connect-timeout 2 -m 5 $url -d (jq -nc --arg n $name '{name: $n}') 2>/dev/null | string collect)
    printf '%s' "$show" | jq -e '.model_info' >/dev/null 2>&1; or return 1

    # GGUF carries the expert counts in model_info; a dense GGUF has a plain feed_forward_length
    set -l arch (printf '%s' "$show" | jq -r '.model_info
        | (to_entries | map(select(.key | endswith(".expert_count"))) | .[0].value // 0) as $n
        | (to_entries | map(select(.key | endswith(".expert_used_count"))) | .[0].value // "?") as $u
        | if $n > 0 then "MoE \($u)/\($n)"
          elif keys | any(endswith(".feed_forward_length")) then "dense"
          else "" end')

    # safetensors models expose only a few model_info keys — the tensor names tell instead
    # (expert counts are not among them, so just "MoE")
    if test -z "$arch"
        set arch (curl -s --connect-timeout 2 -m 10 $url -d (jq -nc --arg n $name '{name: $n, verbose: true}') 2>/dev/null \
            | jq -r 'if (.tensors // []) | length == 0 then ""
                     elif any(.tensors[]; .name | test("expert")) then "MoE"
                     else "dense" end' 2>/dev/null)
        # No answer at all (not even an empty string): the server went away — don't cache
        set -q arch[1]; or return 1
    end

    mkdir -p (dirname $cache)
    test -f $cache; or echo '{}' >$cache
    set -l tmp (mktemp)
    jq --arg d $digest --arg a "$arch" '.[$d] = $a' $cache >$tmp; and mv $tmp $cache; or rm -f $tmp
    echo $arch
end
