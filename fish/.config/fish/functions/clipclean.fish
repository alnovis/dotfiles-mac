function clipclean --description "Dedent and trim trailing whitespace from clipboard"
    argparse 'h/help' 'f/flat' -- $argv; or return 1

    if set -q _flag_help
        echo "Usage: clipclean [OPTIONS]"
        echo ""
        echo "Clean up clipboard text."
        echo ""
        echo "Default: remove common indentation (dedent) + trim trailing spaces."
        echo "Preserves relative indentation for code/YAML."
        echo ""
        echo "Options:"
        echo "  -f, --flat    Strip all leading whitespace from every line"
        echo "  -h, --help    Show this help"
        return 0
    end

    # --flat: strip all leading + trailing whitespace per line
    if set -q _flag_flat
        pbpaste | tr '\r' '\n' | string trim | pbcopy
        echo "Clipboard cleaned (flat)"
        return 0
    end

    # Dedent mode
    set -l text (pbpaste | tr '\r' '\n' | string collect)
    if test -z "$text"
        echo "Clipboard is empty"
        return 1
    end

    set -l lines (string split \n -- $text)

    # Find minimum indent among non-empty lines
    set -l min_indent -1
    for line in $lines
        if string match -rq '\S' -- $line
            set -l indent (string match -r '^\s*' -- $line)
            set -l len (string length -- $indent)
            if test $min_indent -eq -1; or test $len -lt $min_indent
                set min_indent $len
            end
        end
    end

    # Strip common indent
    if test $min_indent -gt 0
        for i in (seq (count $lines))
            set lines[$i] (string sub -s (math $min_indent + 1) -- $lines[$i])
        end
    end

    # Trim trailing whitespace per line
    for i in (seq (count $lines))
        set lines[$i] (string replace -r '\s+$' '' -- $lines[$i])
    end

    printf '%s\n' $lines | pbcopy
    echo "Clipboard cleaned (dedent)"
end
