function _ai_default_model --description "Resolve model: per-task config (matching provider) > AI_DEFAULT_MODEL > config key model (ollama only); empty if none"
    set -l task $argv[1]
    set -l provider $argv[2]

    # 1. Per-task model — applies only when the runtime provider matches the
    #    provider this task is configured for. A model name is provider-specific
    #    (e.g. an ollama tag), so a --provider override must not leak it across
    #    to a different provider that can't resolve it.
    if test -n "$task"
        set -l v (_ai_config_read "$task"_model)
        if test $status -eq 0; and test -n "$v"
            if test -z "$provider"; or test "$provider" = (_ai_default_provider $task)
                echo $v
                return
            end
        end
    end

    # The default model is an ollama tag; other providers have their own defaults
    # (claude: the CLI's, a runner provider: its first listed model — see _ai_run).
    if test -n "$provider"; and test "$provider" != ollama
        return
    end

    # 2. One-off override from the environment
    if set -q AI_DEFAULT_MODEL; and test -n "$AI_DEFAULT_MODEL"
        echo $AI_DEFAULT_MODEL
        return
    end

    # 3. Config key `model` (project, then global), written by `ai models use MODEL`.
    #    No literal fallback: nothing configured → the caller reports it.
    _ai_config_read model
end
