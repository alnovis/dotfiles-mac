function describe --description "Describe a fish function: summary, source file, and highlighted body (like psql \\d)"
    argparse h/help d/description p/path b/body plain -- $argv; or return 1

    if set -q _flag_help
        echo "Usage: describe [OPTIONS] NAME"
        echo ""
        echo "Describe a fish function like psql's \\d: show its description,"
        echo "source file and line, type, and the syntax-highlighted body."
        echo ""
        echo "Options:"
        echo "  -d, --description  Print only the function's description"
        echo "  -p, --path         Print only the source file path"
        echo "  -b, --body         Print only the (highlighted) body, no header"
        echo "      --plain        Disable syntax highlighting"
        echo "  -h, --help         Show this help"
        echo ""
        echo "Examples:"
        echo "  describe gstat            # full description card"
        echo "  describe -b gstat | less  # just the body"
        echo "  describe -p gstat         # path to the .fish file"
        return 0
    end

    set -l name $argv[1]
    if test -z "$name"
        echo "describe: missing function name" >&2
        echo "Try 'describe --help'." >&2
        return 1
    end

    if test (count $argv) -gt 1
        echo "describe: too many arguments (expected one name)" >&2
        return 1
    end

    # Not a function? Fall back to explaining what it is.
    if not functions -q $name
        if type -q $name
            set_color yellow
            echo "'$name' is not a fish function:"
            set_color normal
            type $name
            return 0
        end
        echo "describe: '$name' is not a known function or command" >&2
        return 1
    end

    # functions -v -D emits exactly 5 lines:
    #   1: source path (or "n/a" / "stdin")
    #   2: autoloaded / not-autoloaded / n/a
    #   3: line number
    #   4: scope-shadowing / no-scope-shadowing / n/a
    #   5: description
    set -l details (functions -v -D $name)
    set -l src_path $details[1]
    set -l autoload $details[2]
    set -l line_no $details[3]
    set -l desc $details[5]

    # Contract the home dir for readability.
    set -l pretty_path $src_path
    if string match -q "$HOME/*" $src_path
        set pretty_path "~/"(string sub -s (math (string length $HOME) + 2) $src_path)
    end

    # --path: just the raw file path (useful for `$EDITOR (describe -p foo)`).
    if set -q _flag_path
        echo $src_path
        return 0
    end

    # --description: just the summary line.
    if set -q _flag_description
        echo $desc
        return 0
    end

    # Decide whether to colorize: honor --plain and non-tty output.
    set -l use_color true
    if set -q _flag_plain; or not isatty stdout
        set use_color false
    end

    set -l highlight $use_color
    if not type -q fish_indent
        set highlight false
    end

    # Body: strip the "# Defined in ..." autoload header, then highlight.
    set -l render_body
    if test "$highlight" = true
        set render_body 'functions $name | string match -rv "^# Defined in " | fish_indent --ansi'
    else
        set render_body 'functions $name | string match -rv "^# Defined in "'
    end

    if set -q _flag_body
        eval $render_body
        return 0
    end

    # Full card: header + body.
    set -l label_color ""
    set -l dim ""
    set -l reset ""
    if test "$use_color" = true
        set label_color (set_color brblue)
        set dim (set_color brblack)
        set reset (set_color normal)
    end

    printf '%sFunction:%s %s\n' $label_color $reset $name
    if test -n "$desc"
        printf '%sSummary: %s %s\n' $label_color $reset $desc
    end
    if test "$src_path" = n/a
        printf '%sDefined: %s %s(built-in / interactive)%s\n' $label_color $reset $dim $reset
    else
        printf '%sDefined: %s %s%s:%s%s\n' $label_color $reset $pretty_path $dim $line_no $reset
    end
    if test "$autoload" = autoloaded
        printf '%sType:    %s autoloaded function\n' $label_color $reset
    else
        printf '%sType:    %s function\n' $label_color $reset
    end
    echo

    eval $render_body
end
