function _ai_pi_session_stats --description "Usage JSON of one pi session file (JSONL): exact tokens, turns, tool calls, model and tool time, failed requests"
    # Usage: _ai_pi_session_stats SESSION.jsonl  → JSON on stdout (nothing for a session with
    # no model answer). The keys of the native drivers' --usage-output (prompt_tokens,
    # completion_tokens, cost) plus .agent, so one footer reads both. A slow agentic run is
    # then either the provider (few turns, long model time, failed requests) or the agent
    # (many turns and tool calls).
    # From the session format of pi 1.4: every assistant message carries usage, durationMs and
    # its toolCall blocks; a toolResult carries the tool's durationMs; a failed request is an
    # assistant message with stopReason "error" and errorMessage (pi retries it).
    # The prompt counts cached tokens too: every turn sends the whole context again. Model time
    # is the answered requests; the failed ones have their own (model + tools + failed ≈ wall).
    # A gateway's error is often an HTML page: its <title> is the message.
    test -f "$argv[1]"; or return 1
    jq -s '
        def ms(xs): if any(xs; .durationMs) then [xs | .durationMs // 0] | add else null end;
        [.[] | select(.type == "message") | .message] as $m
        | ($m | map(select(.role == "assistant"))) as $a
        | ($a | map(select(.stopReason == "error" or .stopReason == "aborted"))) as $err
        | ($a | map(select(.stopReason != "error" and .stopReason != "aborted"))) as $ok
        | ($err | last | .errorMessage) as $e
        | ([$a[].content[]? | select(.type == "toolCall") | .name]) as $calls
        | ($m | map(select(.role == "toolResult"))) as $res
        | ([$a[].usage.cost.total // 0] | add // 0) as $cost
        | if ($a | length) == 0 then empty else {
            prompt_tokens: ([$a[].usage | (.input // 0) + (.cacheRead // 0) + (.cacheWrite // 0)] | add),
            completion_tokens: ([$a[].usage.output // 0] | add),
            completion_tokens_details: {reasoning_tokens: ([$a[].usage.reasoning // 0] | add)},
            cost: (if $cost > 0 then $cost else null end),
            agent: {
                turns: ($ok | length),
                tool_calls: ($calls | length),
                tools: ($calls | group_by(.) | map({name: .[0], count: length}) | sort_by(-.count, .name)),
                model_ms: ms($ok[]),
                tool_ms: ms($res[]),
                errors: ($err | length),
                error_ms: ms($err[]),
                last_error: (if $e == null then null
                    else ($e | if test("<title>") then capture("<title>(?<t>[^<]*)</title>").t
                               else gsub("<[^>]*>"; " ") end
                         | gsub("[|[:space:]]+"; " ") | ltrimstr(" ") | rtrimstr(" ") | .[0:80])
                    end)
            }
        } end
    ' $argv[1]
end
