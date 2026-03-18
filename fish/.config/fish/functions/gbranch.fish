function gbranch --description "Show branch overview: commits and diff stat vs base branch"
    argparse 'h/help' 'no-color' 'stat=' -- $argv; or return 1

    if set -q _flag_help
        echo "Usage: gbranch [OPTIONS] [BASE]"
        echo ""
        echo "Show commits and diff stat of current branch vs base branch."
        echo "Auto-detects base (develop/main/master) or specify manually."
        echo ""
        echo "Options:"
        echo "      --stat=N     Set stat output width (default: terminal width)"
        echo "      --no-color   Disable colored output"
        echo "  -h, --help       Show this help"
        echo ""
        echo "Examples:"
        echo "  gbranch           Compare with auto-detected base"
        echo "  gbranch main      Compare with main"
        return 0
    end

    set -l color_flag --color=always
    if set -q _flag_no_color
        set color_flag --color=never
    end

    set -l repo_root (git rev-parse --show-toplevel 2>/dev/null)
    if test $status -ne 0
        echo "Not a git repository"
        return 1
    end

    set -l repo_name (basename $repo_root)
    set -l branch (git branch --show-current)

    # Determine base branch
    set -l base
    if test (count $argv) -eq 1
        set base $argv[1]
    else if git show-ref --verify --quiet refs/heads/develop
        set base develop
    else if git show-ref --verify --quiet refs/heads/main
        set base main
    else if git show-ref --verify --quiet refs/heads/master
        set base master
    else
        echo "No base branch found, specify manually: gbranch <branch>"
        return 1
    end

    if test "$branch" = "$base"
        echo "Repository: $repo_name ($branch)"
        set_color yellow
        echo "Already on $base — showing unpushed commits"
        set_color normal

        set -l unpushed (git rev-list --count origin/$base..HEAD 2>/dev/null; or echo 0)
        if test "$unpushed" -eq 0
            echo "---"
            echo "Up to date with origin/$base"
            return 0
        end

        echo ""
        set_color green
        echo "Commits:"
        set_color normal
        git log --oneline $color_flag origin/$base..HEAD | while read -l line
            echo "  $line"
        end

        set -l stat_flag --stat
        if set -q _flag_stat
            set stat_flag --stat=$_flag_stat
        else if test -n "$COLUMNS"
            set stat_flag --stat=$COLUMNS
        end

        echo ""
        set_color yellow
        echo "Files:"
        set_color normal
        git diff $color_flag $stat_flag origin/$base..HEAD | string collect | echo (cat)

        set -l nums (git diff --numstat origin/$base..HEAD | string match -rv '^\s*$')
        set -l total_add 0
        set -l total_del 0
        set -l total_files 0
        for line in $nums
            set -l parts (string split \t $line)
            if test "$parts[1]" != "-"
                set total_add (math $total_add + $parts[1])
                set total_del (math $total_del + $parts[2])
            end
            set total_files (math $total_files + 1)
        end

        echo "---"
        set -l summary "$unpushed unpushed commit(s), $total_files file(s)"
        if test $total_add -gt 0
            set summary "$summary, "(set_color green)"+$total_add"(set_color normal)
        end
        if test $total_del -gt 0
            set summary "$summary, "(set_color red)"-$total_del"(set_color normal)
        end
        echo $summary
        return 0
    end

    # Find merge base
    set -l merge_base (git merge-base origin/$base HEAD 2>/dev/null)
    if test -z "$merge_base"
        set merge_base (git merge-base $base HEAD 2>/dev/null)
        if test -z "$merge_base"
            echo "Cannot find common ancestor with $base"
            return 1
        end
    end

    set -l ahead (git rev-list --count $merge_base..HEAD)

    echo "Repository: $repo_name ($branch)"
    set_color cyan
    echo "Base: $base ($ahead commit(s) ahead)"
    set_color normal

    if test "$ahead" -eq 0
        echo "---"
        echo "No commits ahead of $base"
        return 0
    end

    # Commits
    echo ""
    set_color green
    echo "Commits:"
    set_color normal
    git log --oneline $color_flag $merge_base..HEAD | while read -l line
        echo "  $line"
    end

    # Diff stat
    set -l stat_flag --stat
    if set -q _flag_stat
        set stat_flag --stat=$_flag_stat
    else if test -n "$COLUMNS"
        set stat_flag --stat=$COLUMNS
    end

    echo ""
    set_color yellow
    echo "Files:"
    set_color normal
    git diff $color_flag $stat_flag $merge_base..HEAD | string collect | echo (cat)

    # Summary
    set -l nums (git diff --numstat $merge_base..HEAD | string match -rv '^\s*$')
    set -l total_add 0
    set -l total_del 0
    set -l total_files 0

    for line in $nums
        set -l parts (string split \t $line)
        if test "$parts[1]" != "-"
            set total_add (math $total_add + $parts[1])
            set total_del (math $total_del + $parts[2])
        end
        set total_files (math $total_files + 1)
    end

    echo "---"
    set -l summary "$ahead commit(s), $total_files file(s)"
    if test $total_add -gt 0
        set summary "$summary, "(set_color green)"+$total_add"(set_color normal)
    end
    if test $total_del -gt 0
        set summary "$summary, "(set_color red)"-$total_del"(set_color normal)
    end
    echo $summary
end
