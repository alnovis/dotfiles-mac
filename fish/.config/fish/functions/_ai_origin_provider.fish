function _ai_origin_provider --description "Origin layer of resolved provider for TASK: project|global|default; '+top' suffix if inherited from top-level" --argument-names task
    set -l proj (_ai_project_config_file)
    set -l global_file ~/.config/ai/config

    # Per-task first
    if test -n "$task"
        if test -n "$proj"
            set -l v (_ai_config_read_file $proj "$task"_provider)
            if test $status -eq 0; and test -n "$v"
                echo project
                return 0
            end
        end
        set -l v (_ai_config_read_file $global_file "$task"_provider)
        if test $status -eq 0; and test -n "$v"
            echo global
            return 0
        end
    end

    # Top-level provider key (inherited by task)
    if test -n "$proj"
        set -l v (_ai_config_read_file $proj provider)
        if test $status -eq 0; and test -n "$v"
            echo project+top
            return 0
        end
    end
    set -l v (_ai_config_read_file $global_file provider)
    if test $status -eq 0; and test -n "$v"
        echo global+top
        return 0
    end

    echo default
end
