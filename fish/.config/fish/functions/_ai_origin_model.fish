function _ai_origin_model --description "Origin layer of resolved model for TASK with PROVIDER: project|global|env|—" --argument-names task provider
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

    # The default model (env override, then config key `model`) is ollama-only
    if test -z "$provider"; or test "$provider" = ollama
        if set -q AI_DEFAULT_MODEL; and test -n "$AI_DEFAULT_MODEL"
            echo env
            return 0
        end
        if test -n "$proj"; and _ai_config_read_file $proj model >/dev/null
            echo project
            return 0
        end
        if _ai_config_read_file $global_file model >/dev/null
            echo global
            return 0
        end
    end

    echo —
end
