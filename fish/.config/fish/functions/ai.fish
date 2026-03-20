function ai --description "AI toolkit: chat, code, review, models, stop"
    set -l subcmd $argv[1]

    # Route subcommands
    switch "$subcmd"
        case models
            _ai_models $argv[2..]
        case review
            _ai_review $argv[2..]
        case code
            _ai_code $argv[2..]
        case chat
            _ai_chat $argv[2..]
        case stop
            _ai_stop $argv[2..]
        case --help -h help
            echo "Usage: ai [COMMAND] [OPTIONS] [PROMPT]"
            echo ""
            echo "AI toolkit powered by Ollama."
            echo ""
            echo "Commands:"
            echo "  (none) [PROMPT]      Interactive chat or one-shot prompt"
            echo "  models               Manage models (list, install, rm, use, update, info, prune)"
            echo "  review               AI code review of branch or commits"
            echo "  code                 AI-assisted coding with aider"
            echo "  chat                 Chat model (default: llama3.1:8b)"
            echo "  stop                 Stop running models or server"
            echo ""
            echo "Options (for chat mode):"
            echo "  -m, --model MODEL    Use specific model"
            echo "  -t, --think          Enable thinking mode"
            echo ""
            echo "Examples:"
            echo "  ai                               Interactive chat"
            echo "  ai \"explain this code\"            One-shot question"
            echo "  ai -t \"solve this problem\"        With thinking"
            echo "  git diff | ai \"review this\"       Pipe input as context"
            echo "  ai models list coder              List coding models"
            echo "  ai models install qwen3.5:9b      Install model"
            echo "  ai models use qwen3.5:9b          Set default"
            echo "  ai review --last 3                Review last 3 commits"
            echo "  ai review --lang fr               Review in French"
            echo "  ai code -e src/main/              Edit code with aider"
            echo "  ai stop                           Stop all models"
            echo "  ai stop --server                  Kill Ollama server"
            return 0
        case '*'
            # No subcommand → chat/prompt mode
            _ai_run $argv
    end
end

function _ai_run --description "Run Ollama model interactively or with prompt"
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
        # Pipe mode: buffer stdin, pipe to ollama
        begin
            if test -n "$prompt"
                echo "$prompt"
                echo ""
            end
            cat
        end | ollama run $think_flag $model
    else if test -n "$prompt"
        ollama run $think_flag $model "$prompt"
    else
        ollama run $think_flag $model
    end
end
