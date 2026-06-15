function _ai_provider_claude --description "AI provider plugin: Claude"
    # Contract (called by _ai_run):
    #   --interactive          take over tty (no stdin to consume)
    #   --model M              model name passed through to claude
    #   --think                accepted for interface symmetry; claude ignores
    #
    # Non-interactive: reads stdin (prompt + piped input), writes to stdout.

    argparse 'interactive' 'model=' 'think' -- $argv; or return 1

    if not command -q claude
        set_color red
        echo "Error: claude is not installed" >&2
        set_color normal
        return 1
    end

    set -l model_flag
    test -n "$_flag_model"; and set model_flag --model $_flag_model

    if set -q _flag_interactive
        claude $model_flag
    else
        claude -p $model_flag
    end
end
