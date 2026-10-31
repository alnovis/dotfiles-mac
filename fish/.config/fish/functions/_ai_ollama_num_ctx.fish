function _ai_ollama_num_ctx --description "Size num_ctx for a prompt of CHARS characters: prints num_ctx and the token estimate; fails over the ceiling" --argument-names chars
    # num_ctx = prompt tokens + room for the answer, so the prompt never fills the whole
    # window (that leaves the model no room to generate → empty output). Over the ceiling
    # we fail loudly instead of truncating the prompt into an empty answer.
    set -l chars_per_token 3      # deliberately low, so the token estimate errs high
    set -l reserve 8192           # room for the answer
    set -l floor 8192             # never smaller: small prompts still get a usable window
    set -l step 4096              # round up to a multiple, so similar prompts reuse one size
    set -l ceiling (_ai_ollama_max_ctx)

    set -l prompt_tokens (math "round($chars / $chars_per_token)")
    set -l num_ctx (math "max($floor, ceil(($prompt_tokens + $reserve) / $step) * $step)")

    if test $num_ctx -gt $ceiling
        echo "ollama: prompt ~$prompt_tokens tokens needs ~$num_ctx context, over the $ceiling ceiling. A single-shot would truncate the prompt and the model would return nothing. Use --context-lines 0 (diff-only) or a smaller commit — or raise ollama_max_ctx / AI_OLLAMA_MAX_CTX if you have the RAM." >&2
        return 1
    end
    echo $num_ctx
    echo $prompt_tokens
end
