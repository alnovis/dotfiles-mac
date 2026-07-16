function _ai_origin_model --description "Origin layer of resolved model for TASK with PROVIDER: project|global|env|default|—" --argument-names task provider
    set -l proj (_ai_project_config_file)
    set -l global_file ~/.config/ai/config

    # Per-task in project, then global — only when the runtime provider matches
    # the task's configured provider (mirrors _ai_default_model's guard).
    if test -n "$task"; and begin; test -z "$provider"; or test "$provider" = (_ai_default_provider $task); end
        if test -n "$proj"
            set -l v (_ai_config_read_file $proj "$task"_model)
            if test $status -eq 0; and test -n "$v"
                echo project
                return 0
            end
        end
        set -l v (_ai_config_read_file $global_file "$task"_model)
        if test $status -eq 0; and test -n "$v"
            echo global
            return 0
        end
    end

    # Env var only meaningful for ollama
    if set -q AI_DEFAULT_MODEL; and test -n "$AI_DEFAULT_MODEL"
        if test -z "$provider"; or test "$provider" = ollama
            echo env
            return 0
        end
    end

    # Hardcoded ollama fallback; otherwise no model (provider default)
    if test -z "$provider"; or test "$provider" = ollama
        echo default
        return 0
    end

    echo —
end
