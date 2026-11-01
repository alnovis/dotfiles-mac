function _ai_select_executor --description "Pick the executor for PROVIDER and PROFILE (none|read|edit) [runner]: prints its function, then a label" --argument-names provider profile need
    # docs/refactoring.md §5. claude → the claude CLI runner; ollama single-shot → the
    # native driver (only it honours a per-request num_ctx); everything else → the runner
    # from the agent config key, which must know the provider (it owns the provider config).
    # NEED=runner skips the native drivers — for what only a runner has (resumable sessions).
    # NEED=interactive keeps `ollama run` but skips the OpenAI driver (it has no REPL).
    # A single call to a provider the runner reaches over the OpenAI API goes native too
    # (_ai_provider_openai): no agent in between; config key cloud_driver=runner opts out.
    if test "$provider" = claude
        echo _ai_agent_claude
        echo "claude (runner claude, profile $profile)"
        return 0
    end
    if test "$provider" = ollama; and test "$profile" = none; and test "$need" != runner
        echo _ai_provider_ollama
        echo "ollama (native)"
        return 0
    end

    set -l runner (_ai_default_agent); or return 1
    if test "$provider" != ollama; and test "$profile" = none; and test -z "$need"
        and test "$(_ai_config_read cloud_driver)" != runner
        and functions -q _ai_agent_{$runner}_endpoint
        set -l ep (_ai_agent_{$runner}_endpoint $provider "")
        if test "$ep[2]" = openai-completions
            echo _ai_provider_openai
            echo "$provider (native, endpoint from $runner)"
            return 0
        end
    end
    if not _ai_agent_{$runner}_models | string match -q -- (printf '%s\t*' $provider)
        set_color red >&2
        echo "Provider $provider: unknown to runner $runner — configure it in $runner, or pick another provider (ai providers)" >&2
        set_color normal >&2
        return 1
    end
    echo _ai_agent_$runner
    echo "$provider via $runner (profile $profile)"
end
