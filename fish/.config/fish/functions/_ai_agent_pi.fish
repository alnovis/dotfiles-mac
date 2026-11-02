function _ai_agent_pi --description "Runner: pi (any provider in pi's own config, local or cloud)"
    # Runner contract (docs/refactoring.md §4):
    #   --provider P --model M   pi resolves P/M in ~/.pi/agent/models.json (M may already be "P/id")
    #   --tools none|read|edit   none: no tools, no skills, and a system prompt that says so
    #                            (_ai_no_tools_prompt); read: read,grep,find,ls — interactive also keeps
    #                            bash, since a person is watching; edit: full toolset.
    #                            Default: read (an unattended run must not touch the repo).
    #   --skill FILE             appended to the system prompt
    #   --interactive            pi TUI (with --continue / --resume); otherwise `pi -p` reads
    #                            the prompt from stdin and streams the answer to stdout
    #   --no-session             don't persist a pi session
    #   --usage-output FILE      (non-interactive) the run's usage JSON: exact tokens, turns,
    #                            tool calls, model and tool time (_ai_pi_session_stats). The
    #                            session goes to a temp dir instead of --no-session, is read
    #                            after the run and removed — nothing stays behind either way.
    # Any remaining argv is passed straight to pi (e.g. @files).
    argparse 'provider=' 'model=' 'tools=' 'skill=' 'interactive' 'continue' 'resume' 'no-session' 'usage-output=' -- $argv; or return 1

    if not command -q pi
        set_color red
        echo "Error: pi is not installed — brew install pi-coding-agent" >&2
        set_color normal
        return 1
    end

    test "$_flag_provider" = ollama; and begin
        _ai_ensure_running; or return 1
    end

    set -l args
    switch "$_flag_tools"
        case none
            set args --exclude-tools '*' --no-skills --system-prompt (_ai_no_tools_prompt)
        case read ''
            if set -q _flag_interactive
                set args --exclude-tools edit,write
            else
                set args --tools read,grep,find,ls
            end
        case edit
        case '*'
            echo "pi: unknown tool profile '$_flag_tools' (none|read|edit)" >&2
            return 1
    end

    # pi's --provider needs --model, so the provider travels inside the model spec
    # A slash inside the id (huihui_ai/glm…, ycloud/…/latest) is not a provider prefix
    if test -n "$_flag_model"
        if test -z "$_flag_provider"; or string match -q -- "$_flag_provider/*" $_flag_model
            set -a args --model $_flag_model
        else
            set -a args --model $_flag_provider/$_flag_model
        end
    end

    set -q _flag_skill; and set -a args --append-system-prompt $_flag_skill
    set -l sdir
    if set -q _flag_usage_output; and not set -q _flag_interactive
        set sdir (mktemp -d)
        set -a args --session-dir $sdir
    else if set -q _flag_no_session
        set -a args --no-session
    end

    if set -q _flag_interactive
        set -q _flag_continue; and set -a args --continue
        set -q _flag_resume; and set -a args --resume
        pi $args $argv
    else
        pi -p $args $argv
        set -l rc $status
        if test -n "$sdir"
            set -l session (find $sdir -name '*.jsonl' -type f | head -1)
            test -n "$session"; and _ai_pi_session_stats $session >$_flag_usage_output
            rm -rf $sdir
        end
        return $rc
    end
end
