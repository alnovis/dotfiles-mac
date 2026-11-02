function _ai_pi_session_stats --description "Usage JSON of one pi session file (JSONL): exact tokens, turns, tool calls, model and tool time, failed requests"
    # Usage: _ai_pi_session_stats SESSION.jsonl  → JSON on stdout (nothing for a session with
    # no model answer). The keys of the native drivers' --usage-output (prompt_tokens,
    # completion_tokens, cost) plus .agent, so one footer reads both. A slow agentic run is
    # then either the provider (few turns, long model time, failed requests) or the agent
    # (many turns and tool calls).
    # From the session format of pi 1.4: every assistant message carries usage, durationMs and
    # its toolCall blocks; a toolResult carries the tool's durationMs; a failed request is an
    # assistant message with stopReason "error" and errorMessage (pi retries it).
    # The prompt counts cached tokens too: every turn sends the whole context again.
    test -f "$argv[1]"; or return 1
    jq -s '
        [.[] | select(.type == "message") | .message] as $m
        | ($m | map(select(.role == "assistant"))) as $a
        | ($a | map(select(.stopReason == "error" or .stopReason == "aborted"))) as $err
        | ([$a[].content[]? | select(.type == "toolCall") | .name]) as $calls
        | ($m | map(select(.role == "toolResult"))) as $res
        | ([$a[].usage.cost.total // 0] | add // 0) as $cost
        | if ($a | length) == 0 then empty else {
            prompt_tokens: ([$a[].usage | (.input // 0) + (.cacheRead // 0) + (.cacheWrite // 0)] | add),
            completion_tokens: ([$a[].usage.output // 0] | add),
            completion_tokens_details: {reasoning_tokens: ([$a[].usage.reasoning // 0] | add)},
            cost: (if $cost > 0 then $cost else null end),
            agent: {
                turns: (($a | length) - ($err | length)),
                tool_calls: ($calls | length),
                tools: ($calls | group_by(.) | map({name: .[0], count: length}) | sort_by(-.count, .name)),
                model_ms: (if any($a[]; .durationMs) then [$a[].durationMs // 0] | add else null end),
                tool_ms: (if any($res[]; .durationMs) then [$res[].durationMs // 0] | add else null end),
                errors: ($err | length),
                last_error: ($err | last | .errorMessage // null)
            }
        } end
    ' $argv[1]
end
