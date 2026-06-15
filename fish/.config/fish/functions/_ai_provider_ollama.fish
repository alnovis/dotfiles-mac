function _ai_provider_ollama --description "AI provider plugin: Ollama"
    # Contract (called by _ai_run):
    #   --interactive          take over tty (no stdin to consume)
    #   --model M              model name; falls back to _ai_default_model
    #   --think                enable thinking mode
    #
    # Non-interactive: reads stdin (prompt + piped input), writes to stdout.

    argparse 'interactive' 'model=' 'think' -- $argv; or return 1

    _ai_ensure_running; or return 1

    set -l model $_flag_model
    test -z "$model"; and set model (_ai_default_model)

    set -l flags --think=false
    set -q _flag_think; and set flags --think=true

    if set -q _flag_interactive
        ollama run $flags $model
    else
        set -a flags --nowordwrap
        ollama run $flags $model
    end
end
