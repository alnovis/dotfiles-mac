function _ai_models_label --description "Assign a grouping label to a model (or --seed from heuristics)"
    set -l labels_file ~/.config/ai/model-labels

    if contains -- --help $argv; or contains -- -h $argv
        echo "Usage: ai models label MODEL LABEL"
        echo "       ai models label --seed"
        echo ""
        echo "Assign a single grouping label to MODEL (drives the groups in 'ai models list')."
        echo "Labels are lowercased and case-insensitive; 'general' is reserved for the"
        echo "unlabeled bucket, so 'label MODEL general' just clears the label."
        echo ""
        echo "  --seed   Populate initial labels from name heuristics (coder/devstral -> coding,"
        echo "           vl/vision -> vision) without overwriting labels you already set."
        echo ""
        echo "Examples:"
        echo "  ai models label north-mini-code-1.0:latest coding"
        echo "  ai models label ornith:9b coding"
        echo "  ai models label --seed"
        return 0
    end

    if contains -- --seed $argv
        _ai_models_label_seed
        return $status
    end

    set -l model $argv[1]
    set -l label (string lower -- $argv[2])

    if test -z "$model"; or test -z "$label"
        set_color red
        echo "Usage: ai models label MODEL LABEL  (or: ai models label --seed)"
        set_color normal
        return 1
    end

    if test "$label" = general
        _ai_config_remove_file $labels_file $model
        echo "Cleared label for $model (general = unlabeled)"
        return 0
    end

    _ai_config_write_file $labels_file $model $label
    set_color green
    echo "Labeled $model -> $label"
    set_color normal
end

function _ai_models_label_seed --description "Populate model labels from name heuristics (non-destructive)"
    set -l labels_file ~/.config/ai/model-labels
    set -l count 0

    for name in (_ai_get_installed_names)
        # Skip models that already have an explicit label.
        set -l existing (_ai_config_read_file $labels_file $name)
        if test $status -eq 0; and test -n "$existing"
            continue
        end

        set -l lower (string lower $name)
        set -l label
        if string match -qi "*coder*" $lower; or string match -qi "*devstral*" $lower
            set label coding
        else if string match -qi "*vl*" $lower; or string match -qi "*vision*" $lower
            set label vision
        end

        if test -n "$label"
            _ai_config_write_file $labels_file $name $label
            printf "  %-44s -> %s\n" $name $label
            set count (math $count + 1)
        end
    end

    echo "Seeded $count label(s). Heuristics miss novel names -- label the rest by hand:"
    echo "  ai models label MODEL LABEL"
end
