function _ai_config_remove_file --description "Remove KEY from FILE" --argument-names file key
    if not test -f $file
        return 0
    end

    set -l lines (string match -rv "^$key=" <$file)
    if test (count $lines) -eq 0
        : >$file
    else
        printf '%s\n' $lines >$file
    end
end
