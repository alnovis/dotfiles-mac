function ai-models --description "List downloaded Ollama models"
    if contains -- --help $argv; or contains -- -h $argv
        echo "Usage: ai-models"
        echo ""
        echo "List downloaded Ollama models and running instances."
        return 0
    end

    if not command -q ollama
        echo "Ollama is not installed"
        return 1
    end

    set_color cyan
    echo "Downloaded:"
    set_color normal
    ollama list 2>/dev/null; or echo "  (ollama not running)"

    if pgrep -q ollama
        echo ""
        set_color green
        echo "Running:"
        set_color normal
        ollama ps 2>/dev/null
    end
end
