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

        # The server only: a bare `pkill ollama` also kills `ollama pull` / `ollama run`
        # clients in other terminals
        pkill -f 'ollama serve'

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
        # `qwen3` and the running `qwen3:latest` are the same model
        set -l want (_ai_model_norm $argv[1])
        set -l normalized
        for m in $running_models
            set -a normalized (_ai_model_norm $m)
        end
        if not contains -- $want $normalized
            set_color red
            echo "Error: model '$argv[1]' is not running"
            set_color normal
            echo "Running: $running_models"
            return 1
        end

        ollama stop $want
        echo "---"
        set_color green
        echo "Stopped: $want"
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
