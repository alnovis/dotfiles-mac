function _ai_session_progress --description "Where an agentic pi run is, from its session dir: TURNS, LAST TOOL, IDLE SECONDS, PROVIDER/MODEL, CONTEXT TOKENS, PHASE, ACTIVITY (tab-separated)"
    # pi writes the session file entry by entry while it runs (_ai_agent_pi gives it the dir),
    # so the live line can say what the run is doing, as the old native loop's line did:
    # the model, its turn, whether the model or a tool is at work, how full the context is
    # (the last turn's prompt: every turn sends the whole context again), and how long the
    # session has been quiet — a provider that hangs shows as a growing idle time.
    # PHASE: "model" (waiting for the model's next answer), or "tool NAME ARG" while the
    # tools of the last answer run. grep and tail, not jq over the file: it is read every
    # second and can be megabytes.
    # ACTIVITY, while the model is at work: "thinking N" or "writing N" (characters of its
    # reasoning or of its answer so far), from the pulse file ai-guard keeps in the dir
    # ("THINKING TEXT"); "reading" when its turn has begun and nothing has streamed yet: it
    # reads the whole context again first, minutes of silence on a local model that looked
    # like a hang. pi writes an answer to the session only once it is whole, so the session
    # alone said "no answer for 6m" of a model writing one long answer. A pulse newer than
    # the session is this answer's: it is then the idle time too. Empty while a tool runs.
    # A request pi gave up on (stopReason "error": "Request timed out." after httpIdleTimeoutMs
    # with no byte, a local model still reading its prompt) is no turn; pi retries it. While it
    # does, ACTIVITY is "retry N MESSAGE": the line read "turn 2 | reading context" of a run
    # looping on its first request.
    set -l f (path filter -f $argv[1]/*.jsonl)[1]
    if test -z "$f"
        # No pi session: a native driver's run, its stream in the dir (_ai_stream_activity).
        # No turns and no tools; the model and the prompt size as the driver wrote them
        # ("PROVIDER/MODEL" in model, "PROMPT_TOKENS WINDOW" in ctx).
        test -f $argv[1]/stream; or return 1
        set -l model (string trim <$argv[1]/model 2>/dev/null)
        set -l ctx (string split ' ' -- (string trim <$argv[1]/ctx 2>/dev/null))
        printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "" "" (path mtime --relative $argv[1]/stream) "$model" "$ctx[1]" model (_ai_stream_activity $argv[1])
        return 0
    end
    set -l stops (grep '"role":"assistant"' $f | jq -r '.message.stopReason // ""' 2>/dev/null)
    set -l turns (count (string match -v -- error $stops))
    # The failed requests since the last answered one
    set -l retry 0
    set -l i (count $stops)
    while test $i -gt 0; and test "$stops[$i]" = error
        set retry (math $retry + 1)
        set i (math $i - 1)
    end
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
    set -l activity ""
    test "$phase" = model; and set activity reading
    if test "$phase" = model; and test $retry -gt 0
        set -l why (grep '"role":"assistant"' $f | tail -1 | jq -r '.message.errorMessage // "failed"' 2>/dev/null)
        set activity "retry $retry "(string shorten -m 40 -c ... -- "$why")
    end
    set -l pulse $argv[1]/pulse
    # Newer by a second at least: the last pulse of an answer and the answer itself land in
    # the session in the same second
    if test "$phase" = model; and test -f $pulse; and test (path mtime $pulse) -gt (path mtime $f)
        set idle (path mtime --relative $pulse)
        # Read between ai-guard's truncate and write the file is empty ("Invalid number" every
        # few seconds on the live line): only a pulse of numbers counts, else the activity stays
        set -l n (string trim <$pulse 2>/dev/null | string match -r '^\d+(?: \d+)?$' | string split ' ')
        if set -q n[1]
            # One number: a pulse from before the two were counted apart, all of it text
            set -q n[2]; or set -p n 0
            if test "$n[2]" -gt 0
                set activity "writing $n[2]"
            else if test "$n[1]" -gt 0
                set activity "thinking $n[1]"
            end
        end
    end
    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\n' $turns "$call" $idle "$model" "$ctx" "$phase" "$activity"
end
