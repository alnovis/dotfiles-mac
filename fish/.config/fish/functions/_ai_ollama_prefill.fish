function _ai_ollama_prefill --description "How long MODEL reads a prompt of TOKENS (seconds; nothing when never measured); --record MODEL COUNT NS keeps a measured read"
    # ollama sends nothing while it reads a prompt (its prefill): 121k tokens on a dense 27B
    # took longer than the fixed 15 min of request_idle_timeout, and a stuck request looked
    # the same for all those minutes. Each answer's last record tells how long the read took
    # (prompt_eval_count tokens in prompt_eval_duration ns): the rate of the last long read is
    # kept per model, and the next read is expected from it.
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
        jq --arg m $model --argjson c $count --argjson ns $ns '.[$m] = ($c / ($ns / 1e9) | . * 10 | round / 10)' $cache >$tmp
        and mv $tmp $cache; or rm -f $tmp
        return 0
    end
    test -f $cache; or return 0
    jq -r --arg m $model --argjson t $argv[2] '.[$m] // empty | select(. > 0) | $t / . | ceil' $cache 2>/dev/null
end
