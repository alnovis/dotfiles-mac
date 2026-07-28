function _ai_provider_ollama --description "AI provider plugin: Ollama (per-run context sizing via HTTP API)"
    # Contract (called by _ai_run):
    #   --interactive          take over tty (no stdin to consume)
    #   --model M              model name; falls back to _ai_default_model
    #   --think                enable thinking mode
    #   --agentic              accepted for interface symmetry; raw ollama has no
    #                          tools, so it is a no-op here (agentic local = pi/opencode)
    #
    # Non-interactive: reads the prompt from stdin, SIZES the context window to the
    # prompt (num_ctx per request, clamped to a RAM-safe ceiling) so a large embed
    # is not silently truncated — the global OLLAMA_CONTEXT_LENGTH is a one-size cap
    # that is wrong per-task. Streams the response to stdout.
    argparse 'interactive' 'model=' 'think' 'agentic' -- $argv; or return 1

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

    set -l think false
    set -q _flag_think; and set think true

    set -l host http://localhost:11434
    if set -q OLLAMA_HOST; and test -n "$OLLAMA_HOST"
        if string match -q 'http*' -- $OLLAMA_HOST
            set host $OLLAMA_HOST
        else
            set host "http://$OLLAMA_HOST"
        end
    end

    jq -n --arg m $model --arg p "$prompt" --argjson ctx $num_ctx --argjson think $think \
        'if $think then {model:$m, prompt:$p, stream:true, think:true, options:{num_ctx:$ctx}} else {model:$m, prompt:$p, stream:true, options:{num_ctx:$ctx}} end' \
        | curl -s $host/api/generate -d @- \
        | jq -j --unbuffered 'if .error then error(.error) else (.response // empty) end'
end
