function _ai_ensure_running --description "Ensure Ollama server is running"
    # All status/errors go to stderr — this runs inside the provider, whose stdout
    # is captured (e.g. `_ai_run --output FILE`); a stray line on stdout would land
    # in the review/output file.
    if not command -q ollama
        echo "Error: ollama is not installed" >&2
        return 1
    end

    if pgrep -q ollama
        return 0
    end

    echo "Starting Ollama..." >&2
    ollama serve >/dev/null 2>&1 &
    disown

    # Wait for server to be ready (up to 10s)
    for i in (seq 1 20)
        if ollama list &>/dev/null
            return 0
        end
        sleep 0.5
    end

    echo "Error: Ollama failed to start" >&2
    return 1
end
