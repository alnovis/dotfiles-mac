function clipclean --description "Dedent and trim trailing whitespace from clipboard"
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
        if (min_indent < 1) min_indent = 0
        for (i = 1; i <= NR; i++) {
            line = lines[i]
            if (length(line) > min_indent) {
                line = substr(line, min_indent + 1)
            } else if (line ~ /^[[:space:]]*$/) {
                line = ""
            }
            sub(/[[:space:]]+$/, "", line)
            print line
        }
    }
    ' | pbcopy
    echo "Clipboard dedented"
end
