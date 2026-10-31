function _ai_select_executor --description "Pick the executor for PROVIDER and PROFILE (none|read|edit): prints its function, then a label" --argument-names provider profile
    # docs/refactoring.md §5. claude → the claude CLI runner; ollama single-shot → the
    # native driver (only it honours a per-request num_ctx); everything else → the runner
    # from the agent config key, which must know the provider (it owns the provider config).
    if test "$provider" = claude
        echo _ai_agent_claude
        echo "claude (runner claude, profile $profile)"
        return 0
    end
    if test "$provider" = ollama; and test "$profile" = none
        echo _ai_provider_ollama
        echo "ollama (native)"
        return 0
    end

    set -l runner (_ai_default_agent); or return 1
    if not _ai_agent_{$runner}_models | string match -q -- (printf '%s\t*' $provider)
        set_color red >&2
        echo "Provider $provider: unknown to runner $runner — configure it in $runner, or pick another provider (ai providers)" >&2
        set_color normal >&2
        return 1
    end
    echo _ai_agent_$runner
    echo "$provider via $runner (profile $profile)"
end
