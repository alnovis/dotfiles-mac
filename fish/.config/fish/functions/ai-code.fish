function ai-code --description "Run aider with Ollama for AI-assisted coding"
    if contains -- --help $argv; or contains -- -h $argv
        echo "Usage: ai-code [OPTIONS] [FILES...]"
        echo ""
        echo "Run aider with Ollama in current repository."
        echo "Default: ask mode (read-only). Use -e/--edit to allow edits."
        echo "Uses AI_DEFAULT_MODEL if set, otherwise deepseek-coder-v2:16b."
        echo ""
        echo "Options:"
        echo "  -e, --edit       Allow code editing (default: ask-only mode)"
        echo "  --model MODEL    Override model (format: ollama/MODEL)"
        echo "  Any other aider flags are passed through."
        echo ""
        echo "Examples:"
        echo "  ai-code src/main/                    Analyze code (read-only)"
        echo "  ai-code -e src/main/                 Edit mode"
        echo "  ai-code --model ollama/qwen2.5:32b   Use different model"
        echo ""
        echo "See also: ai, ai-models, ollama-stop"
        return 0
    end

    if not command -q aider
        set_color red
        echo "Error: aider is not installed — brew install aider"
        set_color normal
        return 1
    end

    _ai_ensure_running; or return 1

    set -l model deepseek-coder-v2:16b
    if set -q AI_DEFAULT_MODEL; and test -n "$AI_DEFAULT_MODEL"
        set model $AI_DEFAULT_MODEL
    end

    # Check for --edit flag
    set -l chat_mode --chat-mode ask
    set -l passthrough
    for arg in $argv
        if test "$arg" = -e; or test "$arg" = --edit
            set chat_mode --chat-mode code
        else
            set -a passthrough $arg
        end
    end

    # Build command
    set -l cmd aider --dark-mode --no-auto-commits $chat_mode
    if contains -- --model $passthrough
        $cmd $passthrough
    else
        $cmd --model ollama/$model $passthrough
    end
end
