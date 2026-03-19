function ai --description "Run Ollama model interactively"
    if contains -- --help $argv; or contains -- -h $argv
        echo "Usage: ai [MODEL]"
        echo ""
        echo "Start Ollama (if needed) and run a model interactively."
        echo "Uses AI_DEFAULT_MODEL if set, otherwise deepseek-coder-v2:16b."
        echo ""
        echo "Examples:"
        echo "  ai                          Run default model"
        echo "  ai llama3.1:8b              Run specific model"
        echo ""
        echo "See also: ai-code, ai-chat, ai-models, ai-stop"
        return 0
    end

    set -l model deepseek-coder-v2:16b
    if test (count $argv) -ge 1
        set model $argv[1]
    else if set -q AI_DEFAULT_MODEL; and test -n "$AI_DEFAULT_MODEL"
        set model $AI_DEFAULT_MODEL
    end

    _ai_ensure_running; or return 1

    ollama run $model
end
