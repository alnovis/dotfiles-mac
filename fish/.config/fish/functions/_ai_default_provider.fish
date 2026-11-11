function _ai_default_provider --description "Resolve provider: per-task config > global config > ollama"
    set -l task $argv[1]

    if test -n "$task"
        set -l v (_ai_config_read "$task"_provider)
        if test $status -eq 0; and test -n "$v"
            echo $v
            return
        end
    end

    # Verify runs on the review's provider unless told otherwise (_ai_review_verify_flow), so
    # its configured provider is the review's too: with review_provider=X and a global
    # provider=ollama, verify_model was matched against ollama and silently ignored
    if test "$task" = verify
        set -l v (_ai_config_read review_provider)
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
