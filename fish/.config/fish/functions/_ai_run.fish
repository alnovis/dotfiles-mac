function _ai_run --description "Dispatch a prompt to the configured AI provider"
    # Usage: echo "prompt" | _ai_run [flags]
    #    or: _ai_run [flags] "prompt text"
    #
    # Flags: --provider P  --model M  --think  --workdir DIR  --output FILE  --dry-run
    # Provider resolution: --provider flag > config file > default (ollama)
    # Providers are auto-discovered as _ai_provider_<name> functions (see _ai_providers).

    argparse 'provider=' 'model=' 'think' 'workdir=' 'output=' 'dry-run' -- $argv; or return 1

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

    set -l prev_pwd $PWD
    if set -q _flag_workdir
        cd $_flag_workdir; or return 1
    end

    # Interactive iff no prompt, no piped stdin, no output redirect
    set -l interactive 0
    if isatty stdin; and test -z "$prompt"; and test -z "$output"
        set interactive 1
    end

    # /dev/stdout collapses "to file" and "to stdout" branches into one pipeline
    set -l outfile $output
    test -z "$outfile"; and set outfile /dev/stdout

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

    set -l provider_args
    test -n "$_flag_model"; and set -a provider_args --model $_flag_model
    set -q _flag_think; and set -a provider_args --think

    set -l rc 0
    if test $interactive -eq 1
        $provider_fn --interactive $provider_args
        set rc $status
    else
        _ai_pipe_input "$prompt" | $provider_fn $provider_args >$outfile
        set rc $status
    end

    cd $prev_pwd
    return $rc
end
