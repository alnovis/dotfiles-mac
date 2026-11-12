function _ai_ollama_prefill --description "How long MODEL reads a prompt of TOKENS (seconds; nothing when never measured); --record MODEL COUNT NS keeps a measured read"
    # ollama sends nothing while it reads a prompt (its prefill): 121k tokens on a dense 27B
    # took longer than the fixed 15 min of request_idle_timeout, and a stuck request looked
    # the same for all those minutes. Each answer's last record tells how long the read took
    # (prompt_eval_count tokens in prompt_eval_duration ns); the reads are kept per model.
    # A token costs more the longer the prompt before it (it attends to all of them):
    # qwen3.8:27b read 10.5k tokens at 147 tok/s and 32k at 114. So the time per token is
    # fitted as a + b * TOKENS over the kept reads, and the read takes TOKENS * that: 121k
    # comes out at ~34 min where one rate said 18. With one read, or reads of about one size,
    # or a fit that makes no sense (b < 0), the rate of the read nearest in size is used.
    argparse record -- $argv; or return 1
    set -l cache ~/.cache/ai/prefill.json
    set -l model $argv[1]
    if set -q _flag_record
        set -l count $argv[2]
        set -l ns $argv[3]
        # A short read says little of a long one (the fixed cost of a request weighs in it)
        string match -qr '^[0-9]+$' -- "$count"; and test $count -ge 4000; or return 0
        string match -qr '^[0-9]+$' -- "$ns"; and test $ns -gt 0; or return 0
        mkdir -p (dirname $cache)
        test -f $cache; or echo '{}' >$cache
        set -l tmp (mktemp)
        # A read of about the same size replaces the older one; the last 8 are kept
        jq --arg m $model --argjson n $count --argjson ns $ns '
            ($ns / 1e9 | . * 10 | round / 10) as $s
            | .[$m] = ((.[$m] | if type == "array" then . else [] end)
                | map(select((.n - $n) * (.n - $n) > ($n * 0.1) * ($n * 0.1)))
                | . + [{n: $n, s: $s}] | .[-8:])' $cache >$tmp
        and mv $tmp $cache; or rm -f $tmp
        return 0
    end
    test -f $cache; or return 0
    jq -r --arg m $model --argjson t $argv[2] '
        def abs: if . < 0 then -. else . end;
        # the rate of the read nearest in size to $t
        def nearest: min_by(.x - $t | abs) | $t * .y;
        .[$m] // empty | if type == "array" then . else empty end
        | map({x: .n, y: (.s / .n)}) as $p
        | ($p | length) as $k
        | if $k == 0 then empty
          elif $k == 1 or ($p | map(.x) | max) < 1.5 * ($p | map(.x) | min) then $p | nearest
          else
              ($p | map(.x) | add / $k) as $mx
              | ($p | map(.y) | add / $k) as $my
              | (($p | map((.x - $mx) * (.y - $my)) | add) / ($p | map((.x - $mx) * (.x - $mx)) | add)) as $b
              | ($my - $b * $mx) as $a
              | if $b < 0 or $a <= 0 then $p | nearest else $t * ($a + $b * $t) end
          end
        | ceil' $cache 2>/dev/null
end
