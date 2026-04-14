function _ai_provider_run --description "Run a prompt through the configured AI provider"
    # Usage: echo "prompt" | _ai_provider_run [--provider P] [--model M] [--think]
    #    or: _ai_provider_run [--provider P] [--model M] [--think] "prompt text"
    #
    # Provider resolution: --provider flag > config file > default (ollama)

    argparse 'provider=' 'model=' 'think' -- $argv; or return 1

    # Resolve provider
    set -l provider
    if set -q _flag_provider
        set provider $_flag_provider
    else
        set provider (_ai_config_read provider; or echo ollama)
    end

    set -l model $_flag_model
    set -l prompt (string join " " $argv)

    switch $provider
        case ollama
            # Default model
            if test -z "$model"
                if set -q AI_DEFAULT_MODEL; and test -n "$AI_DEFAULT_MODEL"
                    set model $AI_DEFAULT_MODEL
                else
                    set model deepseek-coder-v2:16b
                end
            end

            _ai_ensure_running; or return 1

            set -l think_flag --think=false
            if set -q _flag_think
                set think_flag --think=true
            end

            if not isatty stdin
                begin
                    if test -n "$prompt"
                        echo "$prompt"
                        echo ""
                    end
                    cat
                end | ollama run $think_flag $model
            else if test -n "$prompt"
                echo "$prompt" | ollama run $think_flag $model
            else
                ollama run $think_flag $model
            end

        case claude
            if not command -q claude
                set_color red
                echo "Error: claude is not installed"
                set_color normal
                return 1
            end

            set -l model_flag
            if test -n "$model"
                set model_flag --model $model
            end

            if not isatty stdin
                begin
                    if test -n "$prompt"
                        echo "$prompt"
                        echo ""
                    end
                    cat
                end | claude -p $model_flag
            else if test -n "$prompt"
                claude -p $model_flag "$prompt"
            else
                # Interactive mode
                claude $model_flag
            end

        case '*'
            set_color red
            echo "Unknown provider: $provider" >&2
            set_color normal
            return 1
    end
end
