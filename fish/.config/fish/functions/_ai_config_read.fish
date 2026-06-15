function _ai_config_read --description "Read KEY from project .ai/config (if any) with global ~/.config/ai/config fallback" --argument-names key
    set -l proj (_ai_project_config_file)
    if test -n "$proj"
        set -l v (_ai_config_read_file $proj $key)
        if test $status -eq 0; and test -n "$v"
            echo $v
            return 0
        end
    end

    _ai_config_read_file ~/.config/ai/config $key
end
