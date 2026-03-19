function ai-stop --description "Stop Ollama server"
    if contains -- --help $argv; or contains -- -h $argv
        echo "Usage: ai-stop"
        echo ""
        echo "Stop Ollama server gracefully."
        echo "Shows running models before stopping."
        return 0
    end

    if not pgrep -q ollama
        echo "Ollama is not running"
        return 0
    end

    # Show what's running
    set -l running (ollama ps 2>/dev/null | tail -n +2)
    if test -n "$running"
        set_color yellow
        echo "Running models:"
        set_color normal
        echo "$running"
        echo ""
    end

    pkill ollama

    echo "---"
    set_color green
    echo "Ollama stopped"
    set_color normal
end
