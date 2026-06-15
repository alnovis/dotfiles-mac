function _ai_session_meta --description "Extract stats from session FILE: 'name|created|last_ts|turns|model|tokens_in|tokens_out'" --argument-names file
    if not test -f $file
        return 1
    end

    # Parse with jq slurp: meta from first record, recap from message records
    jq -sr '
        def first_match(cond): first(.[] | select(cond));
        def last_match(cond): last(.[] | select(cond));

        (first_match(.t == "meta")) as $meta |
        ([.[] | select(.t == "assistant")]) as $assists |
        ($assists[-1]) as $last_assist |
        ($assists | length) as $turns |
        ([.[] | select(.t == "assistant") | .usage.prompt_eval_count // 0] | add // 0) as $tok_in |
        ([.[] | select(.t == "assistant") | .usage.eval_count // 0] | add // 0) as $tok_out |
        ([.[] | select(.t == "assistant") | .model // "?"] | unique | join(",")) as $models |
        ([
            ($meta.name // "?"),
            ($meta.created // "?"),
            ($last_assist.ts // $meta.created // "?"),
            ($turns | tostring),
            ($models // "?"),
            ($tok_in | tostring),
            ($tok_out | tostring)
        ] | join("|"))
    ' $file
end
