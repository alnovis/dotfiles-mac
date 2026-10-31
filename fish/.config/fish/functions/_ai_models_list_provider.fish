function _ai_models_list_provider --description "Models of PROVIDER from the runner that owns it (claude: its aliases; all: every provider)" --argument-names provider
    if test "$provider" = claude
        echo "claude (claude CLI):"
        _ai_agent_claude_models | string split -f2 \t | string replace -r '^' '  '
        return 0
    end

    set -l runner (_ai_default_agent); or return 1
    set -l rows (_ai_agent_{$runner}_models)

    if test "$provider" = all
        for p in (printf '%s\n' $rows | string split -f1 \t | sort -u)
            echo "$p (via $runner):"
            printf '%s\n' $rows | string match -r -g (printf '^%s\t(.+)$' (string escape --style=regex -- $p)) | string replace -r '^' '  '
        end
        echo "claude (claude CLI):"
        _ai_agent_claude_models | string split -f2 \t | string replace -r '^' '  '
        return 0
    end

    set -l models (printf '%s\n' $rows | string match -r -g (printf '^%s\t(.+)$' (string escape --style=regex -- $provider)))
    if test (count $models) -eq 0
        set_color red
        echo "Runner $runner knows no provider '$provider' (providers: "(printf '%s\n' $rows | string split -f1 \t | sort -u | string join ", ")", claude)" >&2
        set_color normal
        return 1
    end
    echo "$provider (via $runner):"
    printf '  %s\n' $models
end
