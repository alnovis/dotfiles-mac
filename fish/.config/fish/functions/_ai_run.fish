function _ai_run --description "Dispatch a prompt to the executor for the configured provider"
    # Usage: echo "prompt" | _ai_run [flags]
    #    or: _ai_run [flags] "prompt text"
    #
    # Flags: --provider P  --model M  --think  --no-think  --agentic  --workdir DIR
    #        --output FILE  --thinking-output FILE  --dry-run
    # Provider resolution: --provider flag > config file > default (ollama).
    # Executor selection (claude CLI / native ollama / runner): _ai_select_executor.

    argparse 'provider=' 'model=' 't/think' 'no-think' 'agentic' 'workdir=' 'output=' 'thinking-output=' 'dry-run' -- $argv; or return 1

    set -l provider
    if set -q _flag_provider
        set provider $_flag_provider
    else
        set provider (_ai_config_read provider; or echo ollama)
    end

    # --agentic = explore the repo read-only; otherwise a plain completion
    set -l profile none
    set -q _flag_agentic; and set profile read

    set -l sel (_ai_select_executor $provider $profile); or return 1
    set -l dispatch $sel[1]
    set -l label $sel[2]

    # A runner needs a model: the default ollama model for ollama, otherwise the first
    # model the runner lists for the provider (claude: the CLI picks its own default)
    set -l model $_flag_model
    if test -z "$model"; and test "$dispatch" != _ai_provider_ollama; and test "$provider" != claude
        if test "$provider" = ollama
            set model (_ai_default_model "" ollama)
            if test -z "$model"
                echo "ollama: no model configured — set one with: ai models use MODEL" >&2
                return 1
            end
        else
            set -l runner (string replace _ai_agent_ '' -- $dispatch)
            set model (_ai_agent_{$runner}_models | string match -r -g (printf '^%s\t(.+)$' (string escape --style=regex -- $provider)))[1]
        end
    end

    set -l prompt (string join " " $argv)
    set -l output $_flag_output

    # Reasoning sidecar. Explicit --thinking-output (from _ai_run_watched, already an
    # absolute path) wins and the CALLER owns cleanup. Otherwise, for a direct
    # --output on the native ollama driver, derive one here and own its cleanup ourselves
    # (covers `ai gen commit -o`, `ai … -o`). Only the native driver supports the flag.
    set -l thinking_out $_flag_thinking_output
    set -l thinking_owned 0
    if test -z "$thinking_out"; and test -n "$output"; and test "$dispatch" = _ai_provider_ollama
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
            echo "--- dry-run: prompt that would be sent to $label ---" >&2
            set_color normal >&2
            _ai_pipe_input "$prompt"
        end
        cd $prev_pwd
        return 0
    end

    # Unreachable runner provider: find out in ≤2 s before starting the runner, which
    # would otherwise spend 14–50+ s failing (docs/refactoring.md §5a). ollama is started
    # on demand and claude owns its connectivity, so neither is probed.
    if string match -q '_ai_agent_*' -- $dispatch; and not contains -- $provider ollama claude
        set -l runner (string replace _ai_agent_ '' -- $dispatch)
        if functions -q _ai_agent_{$runner}_probe
            _ai_agent_{$runner}_probe $provider
            if test $status -eq 1
                set -l fb (_ai_fallback_prompt $provider $runner)
                if test -z "$fb"
                    cd $prev_pwd
                    return 1
                end
                set -l from $provider
                set provider ollama
                set model $fb
                set sel (_ai_select_executor ollama $profile); or begin
                    cd $prev_pwd
                    return 1
                end
                set dispatch $sel[1]
                set label "$sel[2], fallback from $from"
                echo "  ↳ running on ollama/$model ($label)" >&2
            end
        end
    end

    # Executor arguments: the native driver takes thinking options; runners take the
    # provider, the tool profile, and run without persisting a session.
    set -l dispatch_args
    test -n "$model"; and set -a dispatch_args --model $model
    if test "$dispatch" = _ai_provider_ollama
        set -q _flag_think; and set -a dispatch_args --think
        set -q _flag_no_think; and set -a dispatch_args --no-think
        test -n "$thinking_out"; and set -a dispatch_args --thinking-output $thinking_out
    else
        set -a dispatch_args --provider $provider --tools $profile
        test $interactive -eq 0; and set -a dispatch_args --no-session
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
