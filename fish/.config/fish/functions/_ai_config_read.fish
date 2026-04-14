function _ai_config_read --description "Read a key from AI config file" --argument-names key
    set -l config_file ~/.config/ai/config

    if not test -f $config_file
        return 1
    end

    while read -l line
        if string match -q "$key=*" $line
            string replace "$key=" "" $line
            return 0
        end
    end <$config_file

    return 1
end
