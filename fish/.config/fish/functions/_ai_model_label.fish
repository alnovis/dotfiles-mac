function _ai_model_label --description "Read the grouping label for MODEL (empty if none). Handles :latest." --argument-names model
    set -l f ~/.config/ai/model-labels

    set -l v (_ai_config_read_file $f $model)
    if test $status -eq 0; and test -n "$v"
        echo $v
        return 0
    end

    # Normalize :latest so a bare label matches an installed ':latest' name and vice versa.
    set -l alt
    if string match -q "*:latest" -- $model
        set alt (string replace -r ':latest$' '' -- $model)
    else
        set alt "$model:latest"
    end
    _ai_config_read_file $f $alt
end
