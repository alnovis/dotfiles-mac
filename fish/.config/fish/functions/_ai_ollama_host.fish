function _ai_ollama_host --description "Base URL of the ollama server: OLLAMA_HOST (as the ollama CLI reads it), else localhost"
    # The one place that knows where ollama is (docs/refactoring.md §7). OLLAMA_HOST may be
    # a bare host:port, like the ollama CLI accepts.
    if set -q OLLAMA_HOST; and test -n "$OLLAMA_HOST"
        if string match -q 'http*' -- $OLLAMA_HOST
            echo $OLLAMA_HOST
        else
            echo "http://$OLLAMA_HOST"
        end
    else
        echo http://localhost:11434
    end
end
