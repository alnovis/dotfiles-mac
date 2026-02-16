function trim --description "Trim leading/trailing whitespace per line (stdin or args)"
    if isatty stdin
        # Called with arguments: trim "  some text  "
        printf '%s\n' $argv | sed 's/^[[:space:]]*//;s/[[:space:]]*$//'
    else
        # Called via pipe: pbpaste | trim
        sed 's/^[[:space:]]*//;s/[[:space:]]*$//'
    end
end
