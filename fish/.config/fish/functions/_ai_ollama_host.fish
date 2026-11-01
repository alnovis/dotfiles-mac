function _ai_ollama_host --description "Base URL of the ollama server: OLLAMA_HOST (as the ollama CLI reads it), else localhost"
    # The one place that knows where ollama is (docs/refactoring.md §7). OLLAMA_HOST may be
    # a bare host:port, like the ollama CLI accepts.
    if set -q OLLAMA_HOST; and test -n "$OLLAMA_HOST"
        if string match -q 'http*' -- $OLLAMA_HOST
            # An explicit scheme keeps its own default port (80 / 443), as in the ollama CLI
            echo $OLLAMA_HOST
        else if string match -qr '^(\[[^]]*\]|[^/:]+):[0-9]+' -- $OLLAMA_HOST
            echo "http://$OLLAMA_HOST"
        else
            # A bare host gets 11434, as in the ollama CLI (OLLAMA_HOST=0.0.0.0 is the
            # documented "listen everywhere" value; without this every call goes to port 80)
            echo "http://$OLLAMA_HOST:11434"
        end
    else
        echo http://localhost:11434
    end
end
