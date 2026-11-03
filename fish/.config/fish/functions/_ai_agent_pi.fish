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
    # An unattended read-only run (ai review --agentic, verify) gets the ai-guard extension:
    # reads only inside the working directory, a turn and a time budget that end in an answer
    # (pi/ai-guard.ts). Config: agent_max_turns (default 30), agent_timeout seconds (900); 0
    # turns a limit off. Not in a session a person watches.
    set -l guard_env
    if not set -q _flag_interactive; and contains -- "$_flag_tools" read ''
        set -l guard $__fish_config_dir/pi/ai-guard.ts
        if test -f $guard
            set -a args --extension $guard
            # Only a value that is set: an empty one would read as 0, the limit off
            set -l v (_ai_config_read agent_max_turns)
            test -n "$v"; and set -a guard_env AI_GUARD_MAX_TURNS=$v
            set v (_ai_config_read agent_timeout)
            test -n "$v"; and set -a guard_env AI_GUARD_TIMEOUT=$v
        end
    end
    set -l sdir
    # AI_PI_SESSION_DIR: the caller's dir for the session, read live for its progress line
    # (_ai_run_progress) — kept for the caller to remove; otherwise a temp dir of our own
    set -l own_sdir 1
    if set -q _flag_usage_output; and not set -q _flag_interactive
        if set -q AI_PI_SESSION_DIR; and test -d "$AI_PI_SESSION_DIR"
            set sdir $AI_PI_SESSION_DIR
            set own_sdir 0
        else
            set sdir (mktemp -d)
        end
        set -a args --session-dir $sdir
    else if set -q _flag_no_session
        set -a args --no-session
    end

    if set -q _flag_interactive
        set -q _flag_continue; and set -a args --continue
        set -q _flag_resume; and set -a args --resume
        pi $args $argv
    else
        if test $own_sdir -eq 0
            # pi's pid in the caller's dir, for its live line to know when the run is gone:
            # pi rewrites its command line (ps shows "pi"), so it cannot be found by it.
            # sh writes its own pid and execs pi, which keeps that pid.
            env $guard_env sh -c 'echo $$ >"$0/pid"; exec pi "$@"' $sdir -p $args $argv
        else
            env $guard_env pi -p $args $argv
        end
        set -l rc $status
        if test -n "$sdir"
            set -l session (find $sdir -name '*.jsonl' -type f | head -1)
            test -n "$session"; and _ai_pi_session_stats $session >$_flag_usage_output
            test $own_sdir -eq 1; and rm -rf $sdir
        end
        return $rc
    end
end
