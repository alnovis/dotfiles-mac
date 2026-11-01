function table --description "Align TSV from stdin into columns (colour-aware); a line without a separator is printed as-is"
    argparse 'h/help' 'header' 'rule' 'right=' 'max=+' 'gap=' 'indent=' 's/sep=' -- $argv; or return 1

    if set -q _flag_help
        echo "Usage: COMMAND | table [OPTIONS]"
        echo ""
        echo "Align tab-separated lines from stdin into columns. Widths are measured without"
        echo "colour codes, so cells may carry set_color. A line without a separator is printed"
        echo "as-is (a group title); the last column is never padded."
        echo ""
        echo "Options:"
        echo "      --header       First line is the header: cyan, with a rule under it"
        echo "      --rule         Close the table with a rule"
        echo "      --right=COLS   Right-align these columns (1-based, comma-separated)"
        echo "      --max=COL:N    Cap a column at N characters, cut with ~ (repeatable)"
        echo "      --gap=N        Spaces between columns (default 2)"
        echo "      --indent=N     Spaces before every line (default 0)"
        echo "  -s, --sep=CHAR     Column separator (default: tab)"
        echo "  -h, --help         Show this help"
        echo ""
        echo "Examples:"
        echo "  printf '%s\t%s\n' Name Size a.txt 12 | table --header --right 2"
        echo "  ai models list   (built on table)"
        return 0
    end

    set -l sep \t
    set -q _flag_sep; and set sep $_flag_sep
    set -l gap 2
    set -q _flag_gap; and set gap $_flag_gap
    # A string, not a command substitution: `string repeat -n 0` prints nothing, and an
    # empty list would make every "$indent$line" below vanish
    set -l indent ""
    set -q _flag_indent; and test $_flag_indent -gt 0; and set indent (string repeat -n $_flag_indent ' ')
    set -l right (string split , -- "$_flag_right")
    set -l caps
    for m in $_flag_max
        set -l p (string split : -- $m)
        set caps[$p[1]] $p[2]
    end

    # A read loop, not (cat): a command substitution inside a function doesn't get the
    # pipe's stdin. read keeps leading spaces, tabs and empty lines.
    set -l lines
    while read -l line
        set -a lines $line
    end

    # Column count, then widths — measured on the (capped) visible text
    set -l ncols 0
    for line in $lines
        string match -q -- "*$sep*" $line; or continue
        set -l n (count (string split -- $sep $line))
        test $n -gt $ncols; and set ncols $n
    end
    if test $ncols -eq 0
        printf '%s\n' $lines
        return 0
    end
    set -l widths (string split ' ' -- (string repeat -n $ncols '0 ' | string trim))
    for line in $lines
        string match -q -- "*$sep*" $line; or continue
        set -l cells (string split -- $sep $line)
        for i in (seq (count $cells))
            set -l cell $cells[$i]
            test -n "$caps[$i]"; and set cell (string shorten --max $caps[$i] --char '~' -- $cell)
            set -l w (string length --visible -- $cell)
            test $w -gt $widths[$i]; and set widths[$i] $w
        end
    end

    set -l total (math (string join + -- $widths) + $gap '*' (math $ncols - 1))
    set -l rule "$indent"(string repeat -n $total -- -)
    set -l spacer ""
    test $gap -gt 0; and set spacer (string repeat -n $gap ' ')

    set -l is_header 0
    set -q _flag_header; and set is_header 1
    for line in $lines
        if not string match -q -- "*$sep*" $line
            echo $indent$line
            continue
        end
        set -l cells (string split -- $sep $line)
        set -l out
        for i in (seq $ncols)
            set -l cell $cells[$i]
            test -n "$caps[$i]"; and set cell (string shorten --max $caps[$i] --char '~' -- $cell)
            # shorten drops a trailing reset when it cuts a coloured cell — re-add it
            string match -q -- '*\e[*' (string escape -- $cell); and set cell "$cell$(set_color normal)"
            if contains -- $i $right
                set cell (string pad -w $widths[$i] -- $cell)
            else if test $i -lt $ncols
                set cell (string pad -r -w $widths[$i] -- $cell)
            end
            set -a out $cell
        end
        set -l row $indent(string join -- $spacer $out | string trim -r)
        if test $is_header -eq 1
            set_color cyan
            echo $row
            set_color normal
            echo $rule
            set is_header 0
        else
            echo $row
        end
    end
    set -q _flag_rule; and echo $rule
    return 0
end
