function _ai_review_changed_files --description "List changed files eligible for full-content embedding as 'lines<TAB>path'"
    # Args: RANGE TIP [FILE_FILTER]
    #   RANGE       git range (e.g. merge_base..HEAD) for --numstat/--name-only
    #   TIP         commit whose file contents/sizes we measure (e.g. HEAD)
    #   FILE_FILTER optional pathspec to scope to
    # Emits one line per embeddable file: "<lines><TAB><path>". Skips deleted files
    # (absent at TIP) and binary files.
    set -l range $argv[1]
    set -l tip $argv[2]
    set -l file_filter $argv[3]

    test -z "$range"; and return 0

    # Binary files show "-" for added/deleted in --numstat; collect to skip them.
    set -l binary
    for line in (git diff $range --numstat 2>/dev/null)
        set -l parts (string split \t -- $line)
        if test (count $parts) -ge 3; and test "$parts[1]" = "-"
            set -a binary $parts[3]
        end
    end

    set -l paths
    if test -n "$file_filter"
        set paths (git diff $range --name-only -- $file_filter 2>/dev/null)
    else
        set paths (git diff $range --name-only 2>/dev/null)
    end

    for path in $paths
        contains -- $path $binary; and continue
        set -l lc (git show "$tip:$path" 2>/dev/null | wc -l | string trim)
        # git show status (pipestatus[1]) non-zero → file absent at tip (deleted).
        test $pipestatus[1] -ne 0; and continue
        printf '%s\t%s\n' $lc $path
    end
end
