function _ai_chat --description "Run Ollama chat model interactively"
    if contains -- --help $argv; or contains -- -h $argv
        echo "Usage: ai chat [MODEL]"
        echo ""
        echo "Start Ollama (if needed) and run a chat model."
        echo "Uses AI_DEFAULT_MODEL if set, otherwise qwen3.5:9b."
        echo ""
        echo "Examples:"
        echo "  ai chat                     Run default chat model"
        echo "  ai chat gemma2:9b           Run specific model"
        echo ""
        echo "See also: ai chat, ai code, ai models, ai stop"
        return 0
    end

    set -l model (_ai_default_model)
    if test (count $argv) -ge 1
        set model $argv[1]
    end

    _ai_ensure_running; or return 1

    ollama run $model
end
