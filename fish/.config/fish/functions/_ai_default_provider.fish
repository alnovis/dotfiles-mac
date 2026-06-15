function _ai_default_provider --description "Resolve provider: per-task config > global config > ollama"
    set -l task $argv[1]

    if test -n "$task"
        set -l v (_ai_config_read "$task"_provider)
        if test $status -eq 0; and test -n "$v"
            echo $v
            return
        end
    end

    set -l global (_ai_config_read provider)
    if test $status -eq 0; and test -n "$global"
        echo $global
        return
    end

    echo ollama
end
