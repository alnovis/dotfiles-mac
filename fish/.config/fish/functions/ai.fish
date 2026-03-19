function ai --description "Run Ollama model interactively or with prompt"
    if contains -- --help $argv; or contains -- -h $argv
        echo "Usage: ai [OPTIONS] [PROMPT]"
        echo ""
        echo "Start Ollama (if needed) and run a model."
        echo "Uses AI_DEFAULT_MODEL if set, otherwise deepseek-coder-v2:16b."
        echo "Thinking mode off by default, use --think to enable."
        echo ""
        echo "Options:"
        echo "  -m, --model MODEL    Use specific model"
        echo "  -t, --think          Enable thinking mode"
        echo ""
        echo "Examples:"
        echo "  ai                              Interactive chat"
        echo "  ai \"explain this code\"           One-shot question"
        echo "  ai -t \"solve this problem\"       With thinking"
        echo "  ai -m llama3.1:8b \"question\"    Specific model"
        echo "  git diff | ai \"review this\"     Pipe input as context"
        echo ""
        echo "See also: ai-code, ai-chat, ai-models, ai-stop"
        return 0
    end

    # Parse flags
    set -l model
    set -l think 0
    set -l prompt_args

    set -l i 1
    while test $i -le (count $argv)
        switch $argv[$i]
            case -m --model
                set i (math $i + 1)
                set model $argv[$i]
            case -t --think
                set think 1
            case '*'
                set -a prompt_args $argv[$i]
        end
        set i (math $i + 1)
    end

    # Default model
    if test -z "$model"
        if set -q AI_DEFAULT_MODEL; and test -n "$AI_DEFAULT_MODEL"
            set model $AI_DEFAULT_MODEL
        else
            set model deepseek-coder-v2:16b
        end
    end

    _ai_ensure_running; or return 1

    # Think flag
    set -l think_flag --think=false
    if test $think -eq 1
        set think_flag --think=true
    end

    # Build prompt from args + stdin
    set -l prompt (string join " " $prompt_args)

    if not isatty stdin
        # Pipe mode: combine prompt + stdin into temp file
        set -l tmpfile (mktemp /tmp/ai-prompt.XXXXXX)
        if test -n "$prompt"
            echo "$prompt" >$tmpfile
            echo "" >>$tmpfile
        end
        cat >>$tmpfile
        ollama run $think_flag $model <$tmpfile
        rm -f $tmpfile
    else if test -n "$prompt"
        ollama run $think_flag $model "$prompt"
    else
        ollama run $think_flag $model
    end
end
