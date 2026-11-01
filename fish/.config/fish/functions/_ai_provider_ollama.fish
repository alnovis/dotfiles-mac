function _ai_provider_ollama --description "AI provider plugin: Ollama (per-run context sizing via HTTP API)"
    # Contract (called by _ai_run):
    #   --interactive          take over tty (no stdin to consume)
    #   --model M              model name; falls back to _ai_default_model (no literal
    #                          fallback: nothing configured is an error)
    #   --think                enable thinking mode
    #   --thinking-output F    write the model's reasoning (the `.thinking` channel) to
    #                          file F instead of dropping it; .response still streams to
    #                          stdout. Internal plumbing flag set by _ai_run(_watched)
    #                          when the report goes to a file — the reasoning sidecar.
    #
    # Non-interactive: reads the prompt from stdin, SIZES the context window to the
    # prompt (num_ctx per request, clamped to a RAM-safe ceiling) so a large embed
    # is not silently truncated — the global OLLAMA_CONTEXT_LENGTH is a one-size cap
    # that is wrong per-task. Streams the response to stdout.
    #   --usage-output F       write the run's token counts to F as JSON (prompt_tokens,
    #                          completion_tokens, tok_s) — read by _ai_run_watched for the
    #                          report footer.
    argparse 'interactive' 'model=' 'think' 'no-think' 'thinking-output=' 'usage-output=' -- $argv; or return 1

    # Resolve the model before touching the server: a missing model is a config error
    set -l model $_flag_model
    test -z "$model"; and set model (_ai_default_model)
    if test -z "$model"
        echo "ollama: no model configured — set one with: ai models use MODEL" >&2
        return 1
    end

    _ai_ensure_running; or return 1

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

    # Size the window to this prompt (_ai_ollama_num_ctx owns the formula and the ceiling)
    set -l sized (_ai_ollama_num_ctx (string length -- "$prompt")); or return 1
    set -l num_ctx $sized[1]
    echo "ollama: num_ctx=$num_ctx (prompt ~$sized[2] tokens, model $model)" >&2

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

    set -l host (_ai_ollama_host)

    # Always send an EXPLICIT think boolean — never omit the field. Omitting it lets a
    # thinking-capable model (laguna, qwen3.x, …) default to reasoning straight INTO
    # .response: the "thinking leaks into the review output" bug. think:false quarantines
    # it (empty .thinking, clean .response); think:true routes reasoning into .thinking,
    # which we drop below (only .response is read) — so the output is the answer either
    # way. Non-thinking models accept think:false as a harmless no-op. Verified on
    # laguna-xs-2.1 (leaked with no field, clean with explicit think:false) and
    # qwen2.5-coder:7b (think:false → no error).
    # One jq for the whole stream: .response to stdout as it arrives; the raw NDJSON is
    # kept, and the reasoning, the token counts and an error are read from it once at the
    # end. (Three jq per chunk — the old sidecar loop — cost ~7 ms a token, a ceiling of
    # ~140 tok/s that a fast MoE model reaches.)
    # Two files: the request is built while tee already writes the stream (one pipeline)
    set -l pfile (mktemp)
    set -l raw (mktemp)
    printf '%s' "$prompt" >$pfile
    jq -cn --arg m $model --rawfile p $pfile --argjson ctx $num_ctx --argjson think $think \
        '{model:$m, prompt:$p, stream:true, think:$think, options:{num_ctx:$ctx}}' \
        | curl -s --no-buffer $host/api/generate -d @- \
        | tee $raw \
        | jq -R -j --unbuffered 'fromjson? | .response // empty'

    set -l rc 0
    set -l err (jq -r 'select(.error) | .error' $raw 2>/dev/null | head -1)
    if test -n "$err"
        echo "ollama: $err" >&2
        set rc 1
    end
    test -n "$_flag_thinking_output"; and jq -j '.thinking // empty' $raw >$_flag_thinking_output 2>/dev/null
    if test -n "$_flag_usage_output"
        jq -c 'select(.done == true and .eval_count)
            | {prompt_tokens: .prompt_eval_count, completion_tokens: .eval_count,
               tok_s: (if (.eval_duration // 0) > 0 then (.eval_count / (.eval_duration / 1e9) | . * 10 | round / 10) else null end)}' \
            $raw 2>/dev/null | tail -1 >$_flag_usage_output
    end
    rm -f $raw $pfile
    return $rc
end
