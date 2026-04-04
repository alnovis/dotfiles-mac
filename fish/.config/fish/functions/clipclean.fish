function clipclean --description "Dedent and trim trailing whitespace from clipboard"
    if contains -- --help $argv; or contains -- -h $argv
        echo "Usage: clipclean"
        echo ""
        echo "Dedent and trim trailing whitespace from clipboard."
        echo "Removes common leading indentation from all lines."
        echo "Result is copied back to clipboard."
        return 0
    end

    pbpaste | awk '
    BEGIN { min_indent = -1 }
    {
        lines[NR] = $0
        if ($0 ~ /[^[:space:]]/) {
            match($0, /^[[:space:]]*/)
            if (min_indent == -1 || RLENGTH < min_indent) min_indent = RLENGTH
        }
    }
    END {
        # If min is 0 but some lines are indented, recompute from indented only
        if (min_indent == 0) {
            min_indent = -1
            for (i = 1; i <= NR; i++) {
                if (lines[i] ~ /[^[:space:]]/) {
                    match(lines[i], /^[[:space:]]*/)
                    if (RLENGTH > 0 && (min_indent == -1 || RLENGTH < min_indent))
                        min_indent = RLENGTH
                }
            }
        }
        if (min_indent < 1) min_indent = 0
        for (i = 1; i <= NR; i++) {
            line = lines[i]
            if (line ~ /^[[:space:]]*$/) {
                line = ""
            } else {
                match(line, /^[[:space:]]*/)
                if (RLENGTH >= min_indent)
                    line = substr(line, min_indent + 1)
            }
            sub(/[[:space:]]+$/, "", line)
            print line
        }
    }
    ' | pbcopy
    echo "Clipboard dedented"
end
