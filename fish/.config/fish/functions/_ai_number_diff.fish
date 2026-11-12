function _ai_number_diff --description "Number a unified diff's hunk lines with their line in the new file: '%5d  line', a removed line blank (stdin -> stdout)"
    # The prompt asks for file:line, and a bare diff only has the @@ headers to count from:
    # a cloud qwen3.8 on a 2.9k-line diff spent its 32768 tokens counting lines ("Need line
    # for ALREADY_SCHEDULED: 54-55... Let's count digest add") and wrote no answer. The same
    # format as _ai_number_lines: a context or added line gets its line in the new file, a
    # removed one blank of the same width. Headers stay as they are (_ai_verify_context finds
    # the changed files by "+++ b/").
    awk '
        /^diff --git / { hunk = 0; print; next }
        /^@@ / {
            hunk = 1
            if (match($0, /\+[0-9]+/)) n = substr($0, RSTART + 1, RLENGTH - 1) + 0
            print; next
        }
        hunk && /^[ +]/ { printf "%5d  %s\n", n, $0; n++; next }
        # a removed line, or "\ No newline at end of file"
        hunk { printf "%5s  %s\n", "", $0; next }
        { print }'
end
