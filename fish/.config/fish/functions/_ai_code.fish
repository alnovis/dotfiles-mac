function _ai_code --description "Interactive coding session with the code task's provider (via its runner)"
    if contains -- --help $argv; or contains -- -h $argv
        echo "Usage: ai code [OPTIONS] [ARGS...]"
        echo ""
        echo "Start an interactive coding session in the current repository with the code"
        echo "task's provider: claude → the claude CLI, any other provider → the runner"
        echo "(config key agent: pi or opencode)."
        echo "Default: no file edits (read profile; pi also keeps bash, prompting in the"
        echo "session). -e/--edit allows edits. Not a sandbox: bash can still touch files."
        echo "Provider/model: code_provider / code_model, overridable with flags."
        echo ""
        echo "Options:"
        echo "  -e, --edit           Allow file edits"
        echo "  --provider P         Override the provider"
        echo "  --model M            Override the model"
        echo "  --dry-run            Show which executor would start, then exit"
        echo "  Any other arguments are passed to the executor (e.g. pi's @files)."
        echo ""
        echo "Examples:"
        echo "  ai code @src/main.rs                 Analyze code (no file edits)"
        echo "  ai code -e @src/main.rs              Edit mode"
        echo "  ai code --provider claude            Coding session in the claude CLI"
        echo ""
        echo "See also: ai review, ai models, ai stop"
        return 0
    end

    # Pull out our options; everything else goes to the executor untouched
    set -l profile read
    set -l opts
    set -l passthrough
    set -l i 1
    while test $i -le (count $argv)
        switch $argv[$i]
            case -e --edit
                set profile edit
            case --dry-run
                set -a opts --dry-run
            case --provider --model
                set -a opts $argv[$i] $argv[(math $i + 1)]
                set i (math $i + 1)
            case '--provider=*' '--model=*'
                set -a opts $argv[$i]
            case '*'
                set -a passthrough $argv[$i]
        end
        set i (math $i + 1)
    end

    _ai_interactive --task code --profile $profile $opts -- $passthrough
end
