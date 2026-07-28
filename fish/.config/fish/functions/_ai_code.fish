function _ai_code --description "Run pi with Ollama for AI-assisted coding"
    if contains -- --help $argv; or contains -- -h $argv
        echo "Usage: ai code [OPTIONS] [FILES...]"
        echo ""
        echo "Run pi with Ollama in current repository."
        echo "Default: no file edits (edit/write disabled); read + bash stay on and"
        echo "pi prompts before each bash command interactively. -e/--edit allows edits."
        echo "Note: not a sandbox -- bash can still touch files. Use -p at your own risk."
        echo "Uses AI_DEFAULT_MODEL if set, otherwise the resolved code model."
        echo ""
        echo "Options:"
        echo "  -e, --edit       Allow file edits (default: edits off; bash still available)"
        echo "  --model MODEL    Override model (format: ollama/MODEL)"
        echo "  Any other pi flags are passed through."
        echo ""
        echo "Files: use pi's @-syntax to add files to context, e.g. ai code @src/main.rs"
        echo ""
        echo "Examples:"
        echo "  ai code @src/main.rs                 Analyze code (no file edits)"
        echo "  ai code -e @src/main.rs              Edit mode"
        echo "  ai code --model ollama/qwen2.5-coder:32b @src/"
        echo ""
        echo "See also: ai review, ai models, ai stop"
        return 0
    end

    set -l model (_ai_default_model code ollama)

    # Read-only by default (block edit/write; bash stays on for the attended session);
    # -e/--edit enables the full toolset. All pi/ollama mechanics live in _ai_agent_pi.
    set -l policy --exclude-tools edit,write
    set -l passthrough
    for arg in $argv
        if test "$arg" = -e; or test "$arg" = --edit
            set policy --edit
        else
            set -a passthrough $arg
        end
    end

    # A user-supplied --model (in passthrough) wins over the resolved default.
    set -l model_args --model $model
    contains -- --model $passthrough; and set model_args

    _ai_agent_pi --interactive --provider ollama $policy $model_args $passthrough
end
