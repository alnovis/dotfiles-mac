function _ai_stop --description "Stop running models or Ollama server"
    if contains -- --help $argv; or contains -- -h $argv
        echo "Usage: ai stop [OPTIONS] [MODEL]"
        echo ""
        echo "Stop running Ollama models or the server."
        echo ""
        echo "Commands:"
        echo "  (none)           Stop all running models"
        echo "  MODEL            Stop a specific model"
        echo "  --server         Stop Ollama server entirely"
        echo ""
        echo "Examples:"
        echo "  ai stop                     Stop all models"
        echo "  ai stop deepseek-coder-v2   Stop specific model"
        echo "  ai stop --server            Kill Ollama server"
        return 0
    end

    if not pgrep -q ollama
        echo "Ollama is not running"
        return 0
    end

    # --server: kill everything
    if contains -- --server $argv
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
        echo "Ollama server stopped"
        set_color normal
        return 0
    end

    # Get running models
    set -l running_models (ollama ps 2>/dev/null | tail -n +2 | awk '{print $1}')

    if test (count $running_models) -eq 0
        echo "No models running"
        return 0
    end

    # Stop specific model
    if test (count $argv) -ge 1
        if not contains -- $argv[1] $running_models
            set_color red
            echo "Error: model '$argv[1]' is not running"
            set_color normal
            echo "Running: $running_models"
            return 1
        end

        ollama stop $argv[1]
        echo "---"
        set_color green
        echo "Stopped: $argv[1]"
        set_color normal
        return 0
    end

    # Stop all running models
    set_color yellow
    echo "Stopping:"
    set_color normal
    for m in $running_models
        echo "  $m"
        ollama stop $m
    end

    echo "---"
    set_color green
    echo "All models stopped"
    set_color normal
end
