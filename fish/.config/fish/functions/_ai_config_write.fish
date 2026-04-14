function _ai_config_write --description "Write a key=value to AI config file" --argument-names key value
    set -l config_file ~/.config/ai/config
    mkdir -p (dirname $config_file)

    if test -f $config_file
        # Keep all lines except the one being updated
        set -l lines (string match -rv "^$key=" <$config_file)
        set -a lines "$key=$value"
        printf '%s\n' $lines >$config_file
    else
        echo "$key=$value" >$config_file
    end
end
