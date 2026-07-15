function _ai_models_labels --description "Show the model -> label map used by 'ai models list'"
    set -l labels_file ~/.config/ai/model-labels

    if not test -f $labels_file
        echo "No labels set. Seed defaults with: ai models label --seed"
        return 0
    end

    set -l lines
    while read -l line
        test -z "$line"; and continue
        set -a lines $line
    end <$labels_file

    if test (count $lines) -eq 0
        echo "No labels set. Seed defaults with: ai models label --seed"
        return 0
    end

    set_color cyan
    echo " Model labels (grouped in 'ai models list'; unlabeled = General):"
    set_color normal

    # Sort by label, then model.
    for l in (printf '%s\n' $lines | sort -t= -k2,2 -k1,1)
        set -l parts (string split -m1 "=" $l)
        printf "   %-44s %s\n" $parts[1] $parts[2]
    end
end
