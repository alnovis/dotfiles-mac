function _ai_models_unlabel --description "Remove a model's grouping label (moves it back to General)"
    if contains -- --help $argv; or contains -- -h $argv
        echo "Usage: ai models unlabel MODEL"
        echo ""
        echo "Remove MODEL's grouping label; it returns to the General group."
        return 0
    end

    set -l model $argv[1]
    if test -z "$model"
        set_color red
        echo "Usage: ai models unlabel MODEL"
        set_color normal
        return 1
    end

    set -l labels_file ~/.config/ai/model-labels
    set -l existing (_ai_config_read_file $labels_file $model)
    if test $status -ne 0; or test -z "$existing"
        echo "$model has no label"
        return 0
    end

    _ai_config_remove_file $labels_file $model
    set_color green
    echo "Unlabeled $model (was: $existing)"
    set_color normal
end
