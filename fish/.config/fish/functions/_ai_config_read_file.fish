function _ai_config_read_file --description "Read KEY from FILE; emits value to stdout. Returns 1 if file missing or key absent." --argument-names file key
    if not test -f $file
        return 1
    end

    while read -l line
        if string match -q "$key=*" $line
            string replace "$key=" "" $line
            return 0
        end
    end <$file

    return 1
end
