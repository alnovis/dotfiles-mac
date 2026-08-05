function _ai_provider_ollama --description "AI provider plugin: Ollama (per-run context sizing via HTTP API)"
    # Contract (called by _ai_run):
    #   --interactive          take over tty (no stdin to consume)
    #   --model M              model name; falls back to _ai_default_model
    #   --think                enable thinking mode
    #   --agentic              accepted for interface symmetry; raw ollama has no
    #                          tools, so it is a no-op here (agentic local = pi/opencode)
    #   --thinking-output F    write the model's reasoning (the `.thinking` channel) to
    #                          file F instead of dropping it; .response still streams to
    #                          stdout. Internal plumbing flag set by _ai_run(_watched)
    #                          when the report goes to a file — the reasoning sidecar.
    #
    # Non-interactive: reads the prompt from stdin, SIZES the context window to the
    # prompt (num_ctx per request, clamped to a RAM-safe ceiling) so a large embed
    # is not silently truncated — the global OLLAMA_CONTEXT_LENGTH is a one-size cap
    # that is wrong per-task. Streams the response to stdout.
    argparse 'interactive' 'model=' 'think' 'no-think' 'agentic' 'thinking-output=' -- $argv; or return 1

    _ai_ensure_running; or return 1

    set -l model $_flag_model
    test -z "$model"; and set model (_ai_default_model)

    if set -q _flag_interactive
        # Interactive chat keeps the CLI REPL (the API is request/response).
        set -l flags --think=false
        set -q _flag_think; and set flags --think=true
        ollama run $flags $model
        return $status
    end

    if not command -q jq
        echo "Error: jq is required for the ollama provider (context sizing)" >&2
        return 1
    end

    # Read the whole prompt from stdin. `read -z` (NUL-delimited) slurps the entire
    # stream into one var — command substitution `(cat)` does NOT inherit the
    # function's piped stdin in this shell, so it must be a direct `read`.
    read -lz prompt

    # Size num_ctx = prompt tokens + output reserve, so the prompt NEVER fills the
    # whole window (which leaves the model no room to generate → empty output — the
    # exact bug of a hard cap that clamps num_ctx *below* the prompt size). Tokens
    # estimated at ~3 chars/token (biased to over-estimate). If the prompt+reserve
    # exceeds the RAM ceiling, fail loudly rather than truncate into an empty result.
    set -l chars (string length -- "$prompt")
    set -l ceiling 131072
    set -q AI_OLLAMA_MAX_CTX; and test -n "$AI_OLLAMA_MAX_CTX"; and set ceiling $AI_OLLAMA_MAX_CTX
    set -l floor 8192
    set -l reserve 8192
    set -l prompt_tokens (math "round($chars / 3)")
    set -l num_ctx (math "max($floor, ceil(($prompt_tokens + $reserve) / 4096) * 4096)")

    if test $num_ctx -gt $ceiling
        echo "ollama: prompt ~$prompt_tokens tokens needs ~$num_ctx context, over the $ceiling ceiling. A single-shot would truncate the prompt and the model would return nothing. Use --context-lines 0 (diff-only) or a smaller commit — or raise AI_OLLAMA_MAX_CTX if you have the RAM." >&2
        return 1
    end
    echo "ollama: num_ctx=$num_ctx (prompt ~$prompt_tokens tokens, model $model)" >&2

    # Thinking policy. A thinking-capable model reasons by DEFAULT (deeper reviews —
    # the whole point of picking a reasoner), but that reasoning is routed through
    # ollama's separate `thinking` channel, NOT into .response. The output jq below
    # reads only .response, so the reasoning is naturally dropped and the deliverable
    # stays clean. Sending think:true to a NON-thinking model is a hard error
    # ("does not support thinking"), so gate on the capability. We NEVER omit the field:
    # omitting it is exactly what made laguna dump reasoning into .response (the leak).
    set -l capable 0
    if ollama show $model 2>/dev/null | string match -rq '^\s*thinking\s*$'
        set capable 1
    end
    set -l think false
    if set -q _flag_no_think
        # Explicit fast path: quarantine reasoning (think:false) even on a thinking
        # model. Reasoning generation is the bulk of a thinking model's wall-clock —
        # this trades that depth for speed on demand (`ai review --no-think`).
    else if test $capable -eq 1
        set think true
    else if set -q _flag_think
        echo "ollama: $model does not support thinking — ignoring --think" >&2
    end

    set -l host http://localhost:11434
    if set -q OLLAMA_HOST; and test -n "$OLLAMA_HOST"
        if string match -q 'http*' -- $OLLAMA_HOST
            set host $OLLAMA_HOST
        else
            set host "http://$OLLAMA_HOST"
        end
    end

    # Always send an EXPLICIT think boolean — never omit the field. Omitting it lets a
    # thinking-capable model (laguna, qwen3.x, …) default to reasoning straight INTO
    # .response: the "thinking leaks into the review output" bug. think:false quarantines
    # it (empty .thinking, clean .response); think:true routes reasoning into .thinking,
    # which we drop below (only .response is read) — so the output is the answer either
    # way. Non-thinking models accept think:false as a harmless no-op. Verified on
    # laguna-xs-2.1 (leaked with no field, clean with explicit think:false) and
    # qwen2.5-coder:7b (think:false → no error).
    set -l thinking_out $_flag_thinking_output

    if test -n "$thinking_out"; and test "$think" = true
        # Sidecar split: reasoning is real (think:true) and a destination was given, so
        # route .thinking -> file and .response -> stdout. Done as a per-chunk read loop
        # (like _ai_agent_ollama) because jq writes one output stream — two sinks need
        # two extractions per NDJSON line. fish pipeline bodies run in a subshell (locals
        # are lost), so the error signal is captured to a FILE and checked afterwards.
        : >$thinking_out
        set -l errfile (mktemp)
        jq -cn --arg m $model --arg p "$prompt" --argjson ctx $num_ctx --argjson think $think \
            '{model:$m, prompt:$p, stream:true, think:$think, options:{num_ctx:$ctx}}' \
            | curl -s --no-buffer $host/api/generate -d @- 2>/dev/null | while read -l chunk
            test -z "$chunk"; and continue
            printf '%s' $chunk | jq -j '.thinking // empty' 2>/dev/null >>$thinking_out
            printf '%s' $chunk | jq -j '.response // empty' 2>/dev/null
            printf '%s' $chunk | jq -r 'select(.error) | .error' 2>/dev/null >>$errfile
        end
        if test -s $errfile
            echo "ollama: "(head -1 $errfile) >&2
            rm -f $errfile
            return 1
        end
        rm -f $errfile
    else
        # Fast path: single streaming jq, reasoning dropped (only .response kept). Used
        # when there is no sidecar destination, or the model doesn't reason (think:false
        # → nothing would land in .thinking anyway, so skip the slower per-chunk loop).
        jq -n --arg m $model --arg p "$prompt" --argjson ctx $num_ctx --argjson think $think \
            '{model:$m, prompt:$p, stream:true, think:$think, options:{num_ctx:$ctx}}' \
            | curl -s $host/api/generate -d @- \
            | jq -j --unbuffered 'if .error then error(.error) else (.response // empty) end'
    end
end
