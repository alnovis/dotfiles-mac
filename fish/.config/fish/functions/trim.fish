function trim --description "Trim leading/trailing whitespace per line (stdin or args)"
    if contains -- --help $argv; or contains -- -h $argv
        echo "Usage: trim [TEXT...]"
        echo ""
        echo "Trim leading/trailing whitespace per line."
        echo "Reads from arguments or stdin (pipe)."
        echo ""
        echo "Examples:"
        echo "  trim \"  hello  \""
        echo "  pbpaste | trim"
        return 0
    end

    if isatty stdin
        # Called with arguments: trim "  some text  "
        printf '%s\n' $argv | sed 's/^[[:space:]]*//;s/[[:space:]]*$//'
    else
        # Called via pipe: pbpaste | trim
        sed 's/^[[:space:]]*//;s/[[:space:]]*$//'
    end
end
