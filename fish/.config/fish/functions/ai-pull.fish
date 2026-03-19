function ai-pull --description "Download an Ollama model"
    if contains -- --help $argv; or contains -- -h $argv; or test (count $argv) -eq 0
        echo "Usage: ai-pull <MODEL>"
        echo ""
        echo "Download an Ollama model."
        echo ""
        echo "Examples:"
        echo "  ai-pull llama3.1:8b"
        echo "  ai-pull deepseek-coder-v2:16b"
        echo "  ai-pull codellama:13b"
        return 0
    end

    _ai_ensure_running; or return 1

    set_color cyan
    echo "Pulling: $argv[1]"
    set_color normal
    ollama pull $argv[1]

    if test $status -eq 0
        echo "---"
        set_color green
        echo "Done"
        set_color normal
    end
end
