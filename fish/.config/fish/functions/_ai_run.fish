function _ai_run --description "Dispatch a prompt to the configured AI provider"
    # Usage: echo "prompt" | _ai_run [flags]
    #    or: _ai_run [flags] "prompt text"
    #
    # Flags: --provider P  --model M  --think  --workdir DIR  --output FILE  --dry-run
    # Provider resolution: --provider flag > config file > default (ollama)
    # Providers are auto-discovered as _ai_provider_<name> functions (see _ai_providers).

    argparse 'provider=' 'model=' 'think' 'agentic' 'workdir=' 'output=' 'thinking-output=' 'dry-run' -- $argv; or return 1

    set -l provider
    if set -q _flag_provider
        set provider $_flag_provider
    else
        set provider (_ai_config_read provider; or echo ollama)
    end

    set -l provider_fn _ai_provider_$provider
    if not functions -q $provider_fn
        set_color red
        echo "Unknown provider: $provider (valid: "(string join ", " (_ai_providers))")" >&2
        set_color normal
        return 1
    end

    set -l prompt (string join " " $argv)
    set -l output $_flag_output

    # Reasoning sidecar. Explicit --thinking-output (from _ai_run_watched, already an
    # absolute path) wins and the CALLER owns cleanup. Otherwise, for a direct
    # --output on the ollama provider, derive one here and own its cleanup ourselves
    # (covers `ai gen commit -o`, `ai … -o`). Only ollama supports the flag.
    set -l thinking_out $_flag_thinking_output
    set -l thinking_owned 0
    if test -z "$thinking_out"; and test -n "$output"; and test "$provider" = ollama; and not set -q _flag_agentic
        set thinking_out (_ai_thinking_output_path $output)
        set thinking_owned 1
    end

    set -l prev_pwd $PWD
    if set -q _flag_workdir
        cd $_flag_workdir; or return 1
    end

    # Interactive iff no prompt, no piped stdin, no output redirect
    set -l interactive 0
    if isatty stdin; and test -z "$prompt"; and test -z "$output"
        set interactive 1
    end

    # Dry-run: print the assembled prompt without invoking the provider
    if set -q _flag_dry_run
        if test $interactive -eq 1
            echo "[dry-run] interactive mode — no prompt to preview" >&2
        else
            set_color cyan >&2
            echo "--- dry-run: prompt that would be sent to $provider ---" >&2
            set_color normal >&2
            _ai_pipe_input "$prompt"
        end
        cd $prev_pwd
        return 0
    end

    # Dispatch target: normally the provider. With --agentic on a NON-native provider
    # (e.g. ollama), route through an agent-runner so the model explores the repo with
    # tools; a native provider (claude -p) already does, so it stays as-is.
    set -l dispatch $provider_fn
    set -l dispatch_args
    test -n "$_flag_model"; and set -a dispatch_args --model $_flag_model
    set -q _flag_think; and set -a dispatch_args --think
    set -q _flag_agentic; and set -a dispatch_args --agentic

    if set -q _flag_agentic; and not _ai_provider_agentic_native $provider
        set -l agent (_ai_default_agent)
        set -l agent_fn _ai_agent_$agent
        if not functions -q $agent_fn
            echo "Unknown agent-runner: $agent (valid: "(string join ", " (_ai_agents))")" >&2
            cd $prev_pwd
            return 1
        end
        set dispatch $agent_fn
        # The runner takes provider+model (maps to pi's <provider>/<model>), runs
        # read-only and ephemeral. It does not understand --think/--agentic.
        set dispatch_args --provider $provider --no-session
        test -n "$_flag_model"; and set -a dispatch_args --model $_flag_model
    end

    # Reasoning sidecar is an ollama-provider feature (not the agent runners, not
    # claude which owns its own thinking). Forward it only when dispatching there.
    if test "$dispatch" = _ai_provider_ollama; and test -n "$thinking_out"
        set -a dispatch_args --thinking-output $thinking_out
    end

    set -l rc 0
    if test $interactive -eq 1
        $dispatch --interactive $dispatch_args
        set rc $status
    else if test -n "$output"
        # Real file: redirect stdout there.
        _ai_pipe_input "$prompt" | $dispatch $dispatch_args >$output
        set rc $status
    else
        # No output file: write to fd 1 directly. Never /dev/stdout — that reopens
        # the controlling terminal and escapes an enclosing pipe (e.g. _ai_run_watched's tee).
        _ai_pipe_input "$prompt" | $dispatch $dispatch_args
        set rc $status
    end

    # Sidecar bookkeeping for the path WE derived (explicit --thinking-output is the
    # caller's to clean). Done before restoring PWD so a workdir-relative path resolves.
    # An empty file means the model didn't reason (or wasn't capable) — drop it.
    if test $thinking_owned -eq 1; and test -n "$thinking_out"
        if test -s "$thinking_out"
            echo "  ↳ reasoning -> $thinking_out" >&2
        else
            rm -f "$thinking_out"
        end
    end

    cd $prev_pwd
    return $rc
end
