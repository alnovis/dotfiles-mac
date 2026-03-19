function opencode --description "Run OpenCode with Ollama auto-start"
    if contains -- --help $argv; or contains -- -h $argv
        echo "Usage: opencode [ARGS...]"
        echo ""
        echo "Run OpenCode TUI. Auto-starts Ollama if needed."
        echo "All arguments passed through to opencode."
        return 0
    end

    _ai_ensure_running; or return 1

    command opencode $argv
end
