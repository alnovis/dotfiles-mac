function _ai_config_write_file --description "Write KEY=VALUE to FILE; creates parent dir if needed" --argument-names file key value
    mkdir -p (dirname $file)

    if test -f $file
        set -l lines (string match -rv "^$key=" <$file)
        set -a lines "$key=$value"
        printf '%s\n' $lines >$file
    else
        echo "$key=$value" >$file
    end
end
