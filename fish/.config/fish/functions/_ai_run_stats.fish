function _ai_run_stats --description "A run's stats from the usage JSON of a driver or the pi runner: KEY<TAB>VALUE lines, or with --row one line in fixed columns"
    # Usage: _ai_run_stats [--row] UFILE EST_TOKENS THINKING_BYTES
    # The pairs are the report's "Run: …" line (_ai_run_watched); --row is the run's line in
    # the terminal, fixed widths so the runs of one stage line up whatever order they end in.
    # Exact counts when the driver reported them (native ollama and OpenAI drivers, the pi
    # runner — it adds turns, tools, model time and failed requests), the prompt-size
    # estimate otherwise (opencode, claude). Numbers are cut to k/M: 908996 reads as 909k.
    argparse 'row' -- $argv; or return 1
    set -l ufile $argv[1]
    set -l est_tokens $argv[2]
    set -l thinking_bytes $argv[3]
    set -l defs '
        def k: if . >= 1000000 then "\(. / 100000 | round / 10)M"
               elif . >= 100000 then "\(. / 1000 | round)k"
               elif . >= 1000 then "\(. / 100 | round / 10)k"
               else "\(.)" end;
        def s: if . < 10000 then "\(. / 100 | round / 10)s" else "\(. / 1000 | round)s" end;
        def lpad($n): tostring | ([range(0; $n - length)] | map(" ") | join("")) + .;
        def failed: if (.agent.errors // 0) > 0
            then "\(.agent.errors) failed"
                + (if .agent.error_ms then ", " + (.agent.error_ms | s) else "" end)
                + (if .agent.last_error then " (\(.agent.last_error))" else "" end)
            else empty end;
        def tokens: "\(.prompt_tokens | k)/\(.completion_tokens | k)";'
    if set -q _flag_row
        set -l row (jq -r "$defs"'
            [(if .agent then
                "\(.agent.turns | lpad(3)) turns  \(.agent.tool_calls | lpad(3)) tools  model \(.agent.model_ms // 0 | s | lpad(5))"
              else empty end),
             "\(tokens | lpad(11)) tokens",
             (if .tok_s then "\(.tok_s) tok/s" else empty end),
             (if .cost then "cost \(.cost * 10000 | round / 10000)" else empty end),
             failed] | join("  ")' $ufile 2>/dev/null)
        test -n "$row"; or set row "~"(math "round($est_tokens / 1000)")"k prompt tokens (estimate)"
        printf '%s\n' $row
        return 0
    end
    set -l pairs (jq -r "$defs"'
        (if .agent then
            ["turns", "\(.agent.turns)"],
            ["tools", "\(.agent.tool_calls)"
                + (if .agent.tool_calls > 0
                   then " (" + (.agent.tools | map("\(.name) \(.count)") | join(", ")) + ")" else "" end)
                + (if .agent.tool_ms then " " + (.agent.tool_ms | s) else "" end)],
            (if .agent.model_ms then ["model", (.agent.model_ms | s)] else empty end)
         else empty end),
        ["prompt", "\(.prompt_tokens | k) tokens"],
        ["completion", "\(.completion_tokens | k) tokens"
            + (if (.completion_tokens_details.reasoning_tokens // 0) > 0
               then " (reasoning \(.completion_tokens_details.reasoning_tokens | k))" else "" end)],
        (if .tok_s then ["speed", "\(.tok_s) tok/s"] else empty end),
        (if .cost then ["cost", "\(.cost * 10000 | round / 10000)"] else empty end),
        (if (.agent.errors // 0) > 0 then ["failed requests", failed | sub(" failed"; "")] else empty end)
        | join("\t")' $ufile 2>/dev/null)
    set -q pairs[1]; or set pairs "prompt"\t"~"(math "round($est_tokens / 1000)")"k tokens (estimate)"
    printf '%s\n' $pairs
    test "$thinking_bytes" -gt 0 2>/dev/null; and printf 'thinking\t%s bytes\n' $thinking_bytes
    return 0
end
