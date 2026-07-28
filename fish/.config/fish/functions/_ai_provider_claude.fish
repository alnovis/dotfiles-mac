function _ai_provider_claude --description "AI provider plugin: Claude"
    # Contract (called by _ai_run):
    #   --interactive          take over tty (no stdin to consume)
    #   --model M              model name passed through to claude
    #   --think                accepted for interface symmetry; claude ignores
    #   --agentic              accepted for interface symmetry — `claude -p` is ALWAYS
    #                          tool-grounded (it reads the repo), so at the provider
    #                          level this is a no-op. The review flow uses the flag
    #                          upstream to skip embedding changed files (let claude
    #                          explore instead). NOTE: a true tools-off single-shot is
    #                          NOT available — the documented `--tools ""` does not
    #                          disable tools in this CLI (verified), so we don't fake it.
    #
    # Non-interactive: reads stdin (prompt + piped input), writes to stdout.

    argparse 'interactive' 'model=' 'think' 'agentic' -- $argv; or return 1

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
        # `claude -p` is tool-grounded: it reads the repo to ground its review/verify.
        claude -p $model_flag
    end
end
