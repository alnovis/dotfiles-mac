function _ai_ensure_running --description "Ensure Ollama server is running"
    if not command -q ollama
        set_color red
        echo "Error: ollama is not installed"
        set_color normal
        return 1
    end

    if pgrep -q ollama
        return 0
    end

    set_color yellow
    echo "Starting Ollama..."
    set_color normal
    ollama serve &>/dev/null &
    disown

    # Wait for server to be ready (up to 10s)
    for i in (seq 1 20)
        if ollama list &>/dev/null
            return 0
        end
        sleep 0.5
    end

    set_color red
    echo "Error: Ollama failed to start"
    set_color normal
    return 1
end
