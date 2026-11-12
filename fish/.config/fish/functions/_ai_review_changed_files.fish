function _ai_review_changed_files --description "List changed files eligible for full-content embedding as 'lines<TAB>path<TAB>whole'"
    # Args: RANGE TIP [FILE_FILTER]
    #   RANGE       git range (e.g. merge_base..HEAD) for --numstat/--name-only
    #   TIP         commit whose file contents/sizes we measure (e.g. HEAD)
    #   FILE_FILTER optional pathspec to scope to
    # Emits one line per embeddable file: "<lines><TAB><path><TAB><whole>". Skips deleted
    # files (absent at TIP) and binary files. whole is 1 when the diff shows every line of
    # the file (a file the change adds): embedding it would only repeat the diff.
    set -l range $argv[1]
    set -l tip $argv[2]
    set -l file_filter $argv[3]

    test -z "$range"; and return 0

    # Binary files show "-" for added/deleted in --numstat; collect to skip them. The rest:
    # the lines each file gains and loses
    set -l binary
    set -l stat_paths
    set -l stat_added
    set -l stat_deleted
    for line in (git diff $range --numstat 2>/dev/null)
        set -l parts (string split \t -- $line)
        test (count $parts) -ge 3; or continue
        if test "$parts[1]" = "-"
            set -a binary $parts[3]
        else
            set -a stat_paths $parts[3]
            set -a stat_added $parts[1]
            set -a stat_deleted $parts[2]
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
        set -l whole 0
        set -l i (contains -i -- $path $stat_paths)
        # -ge: wc -l does not count a last line with no newline, numstat does
        and test "$stat_deleted[$i]" = 0; and test "$stat_added[$i]" -ge "$lc"; and set whole 1
        printf '%s\t%s\t%s\n' $lc $path $whole
    end
end
