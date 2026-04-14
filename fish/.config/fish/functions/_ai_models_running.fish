function _ai_models_running --description "Show currently running Ollama models"
    if not pgrep -q ollama
        echo "Ollama is not running"
        return 0
    end

    set -l running (ollama ps 2>/dev/null | tail -n +2)

    if test -z "$running"
        echo "No models running"
        return 0
    end

    set_color green
    echo "Running:"
    set_color normal
    ollama ps 2>/dev/null
end
