function _ai_session_progress --description "Where an agentic pi run is, from its session dir: TURNS, LAST TOOL, IDLE SECONDS, PROVIDER/MODEL, CONTEXT TOKENS, PHASE, STREAMED (tab-separated)"
    # pi writes the session file entry by entry while it runs (_ai_agent_pi gives it the dir),
    # so the live line can say what the run is doing, as the old native loop's line did:
    # the model, its turn, whether the model or a tool is at work, how full the context is
    # (the last turn's prompt: every turn sends the whole context again), and how long the
    # session has been quiet — a provider that hangs shows as a growing idle time.
    # PHASE: "model" (waiting for the model's next answer), or "tool NAME ARG" while the
    # tools of the last answer run. grep and tail, not jq over the file: it is read every
    # second and can be megabytes.
    # STREAMED: characters of the answer being written, from the pulse file ai-guard keeps in
    # the dir. pi writes an answer to the session only once it is whole, so the session alone
    # said "no answer for 6m" of a model writing one long answer. A pulse newer than the
    # session is this answer's: it is then the idle time too.
    set -l f (path filter -f $argv[1]/*.jsonl)[1]
    test -n "$f"; or return 1
    set -l turns (grep -c '"role":"assistant"' $f)
    set -l call (grep '"type":"toolCall"' $f | tail -1 | jq -r '
        [.message.content[]? | select(.type == "toolCall")] | last
        | .name + " " + ((.arguments.path // .arguments.pattern // "") | tostring | split("/") | last | .[0:40])
    ' 2>/dev/null | string trim)
    set -l model (grep -m1 '"type":"model_change"' $f | jq -r '"\(.provider)/\(.modelId)"' 2>/dev/null)
    set -l ctx (grep '"role":"assistant"' $f | tail -1 | jq -r '
        .message.usage | ((.input // 0) + (.cacheRead // 0) + (.cacheWrite // 0))' 2>/dev/null)
    # The last entry says who is at work: an answer with tool calls means its tools run now
    set -l phase model
    tail -1 $f | jq -e '.type == "message" and .message.role == "assistant"
        and any(.message.content[]?; .type == "toolCall")' >/dev/null 2>&1
    and set phase "tool $call"
    set -l idle (path mtime --relative $f)
    set -l streamed ""
    set -l pulse $argv[1]/pulse
    # Newer by a second at least: the last pulse of an answer and the answer itself land in
    # the session in the same second
    if test -f $pulse; and test (path mtime $pulse) -gt (path mtime $f)
        set idle (path mtime --relative $pulse)
        set streamed (string trim <$pulse)
    end
    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\n' $turns "$call" $idle "$model" "$ctx" "$phase" "$streamed"
end
