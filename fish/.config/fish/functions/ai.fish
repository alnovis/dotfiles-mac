function ai --description "Run Ollama model (default: deepseek-coder-v2:16b)"
    if contains -- --help $argv; or contains -- -h $argv
        echo "Usage: ai [MODEL]"
        echo ""
        echo "Start Ollama (if needed) and run a model interactively."
        echo "Default model: deepseek-coder-v2:16b"
        echo ""
        echo "Examples:"
        echo "  ai                          Run default coding model"
        echo "  ai llama3.1:8b              Run specific model"
        echo "  ai codellama:13b            Run codellama"
        echo ""
        echo "See also: ai-chat, ai-models, ai-pull, ai-stop"
        return 0
    end

    set -l model deepseek-coder-v2:16b
    if test (count $argv) -ge 1
        set model $argv[1]
    end

    _ai_ensure_running; or return 1

    ollama run $model
end
