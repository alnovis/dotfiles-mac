function _ai_code --description "Run pi with Ollama for AI-assisted coding"
    if contains -- --help $argv; or contains -- -h $argv
        echo "Usage: ai code [OPTIONS] [FILES...]"
        echo ""
        echo "Run pi with Ollama in current repository."
        echo "Default: read-only (edit/write tools disabled). Use -e/--edit to allow edits."
        echo "Uses AI_DEFAULT_MODEL if set, otherwise the resolved code model."
        echo ""
        echo "Options:"
        echo "  -e, --edit       Allow code editing (default: read-only)"
        echo "  --model MODEL    Override model (format: ollama/MODEL)"
        echo "  Any other pi flags are passed through."
        echo ""
        echo "Files: use pi's @-syntax to add files to context, e.g. ai code @src/main.rs"
        echo ""
        echo "Examples:"
        echo "  ai code @src/main.rs                 Analyze code (read-only)"
        echo "  ai code -e @src/main.rs              Edit mode"
        echo "  ai code --model ollama/qwen2.5-coder:32b @src/"
        echo ""
        echo "See also: ai review, ai models, ai stop"
        return 0
    end

    if not command -q pi
        set_color red
        echo "Error: pi is not installed — brew install pi-coding-agent"
        set_color normal
        return 1
    end

    _ai_ensure_running; or return 1

    set -l model (_ai_default_model code ollama)

    # Read-only by default (block edit/write tools); -e/--edit enables full toolset.
    set -l tool_args --exclude-tools edit,write
    set -l passthrough
    for arg in $argv
        if test "$arg" = -e; or test "$arg" = --edit
            set tool_args
        else
            set -a passthrough $arg
        end
    end

    # Build command
    set -l cmd pi $tool_args
    if contains -- --model $passthrough
        $cmd $passthrough
    else
        $cmd --model ollama/$model $passthrough
    end
end
