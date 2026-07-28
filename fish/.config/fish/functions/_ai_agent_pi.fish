function _ai_agent_pi --description "AI agent-runner plugin: pi (agentic, tool-using; local models via ollama/<model>)"
    # An agent-runner is the second plug-in family, parallel to _ai_provider_<name>:
    # a provider answers from the prompt alone, a runner explores the repo with tools.
    # Contract (mirrors the provider contract, plus a tool policy):
    #   --interactive        take over the tty (pi REPL). Otherwise `pi -p` reads the
    #                        prompt from stdin and exits (one-shot, streams to stdout).
    #   --provider P         maps to pi's "P/<model>" spec (e.g. ollama/qwen2.5-coder:7b).
    #                        For ollama, the local server is ensured running.
    #   --model M            model id
    #   --edit               allow file mutation (full toolset). DEFAULT is read-only:
    #                        an allowlist of read,grep,find,ls (no bash, no write) so an
    #                        UNATTENDED run (e.g. `ai review --agentic`) cannot touch the
    #                        repo. This is the safe default a review needs.
    #   --exclude-tools LIST override the policy with a pi denylist instead (e.g.
    #                        "edit,write" keeps bash on for an attended `ai code` session).
    #   --no-session         ephemeral run (don't persist a pi session)
    # Any remaining argv is passed straight to pi (e.g. @files).
    argparse 'interactive' 'provider=' 'model=' 'edit' 'exclude-tools=' 'no-session' -- $argv; or return 1

    if not command -q pi
        set_color red
        echo "Error: pi is not installed — brew install pi-coding-agent" >&2
        set_color normal
        return 1
    end

    test "$_flag_provider" = ollama; and begin
        _ai_ensure_running; or return 1
    end

    # Tool policy: explicit denylist > --edit (full) > default read-only allowlist.
    set -l tool_args
    if set -q _flag_exclude_tools
        set tool_args --exclude-tools $_flag_exclude_tools
    else if set -q _flag_edit
        set tool_args
    else
        set tool_args --tools read,grep,find,ls
    end
    set -q _flag_no_session; and set -a tool_args --no-session

    set -l model_args
    if test -n "$_flag_model"
        if string match -q '*/*' -- $_flag_model
            set model_args --model $_flag_model            # already a full provider/id spec
        else if test -n "$_flag_provider"
            set model_args --model $_flag_provider/$_flag_model
        else
            set model_args --model $_flag_model
        end
    end

    if set -q _flag_interactive
        pi $tool_args $model_args $argv
    else
        # -p: non-interactive. pi reads the prompt from stdin when no message args.
        pi -p $tool_args $model_args $argv
    end
end
