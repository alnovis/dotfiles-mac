function _ai_fallback_prompt --description "PROVIDER (via RUNNER) is unreachable: offer the native ollama driver; prints the chosen model" --argument-names provider runner
    # docs/refactoring.md §5a. Asks on the terminal itself (/dev/tty): in `-o` runs stderr
    # goes to a log, and the caller's stdin is the prompt pipe. No terminal, or
    # AI_NONINTERACTIVE set (scripts, the test harness) → the error with a rerun hint.
    set -l model (_ai_default_model "" ollama)
    set -l msg "$provider unreachable (via $runner) — off-network?"

    if set -q AI_NONINTERACTIVE; or not sh -c ': </dev/tty' 2>/dev/null
        set_color red >&2
        echo "$msg Rerun with --provider ollama" >&2
        set_color normal >&2
        return 1
    end

    printf '%s Run on ollama/%s instead? [y/N or a model name] ' $msg $model >/dev/tty
    read -l answer </dev/tty
    switch "$answer"
        case y Y yes
            echo $model
        case '' n N no
            return 1
        case '*'
            echo $answer
    end
end
