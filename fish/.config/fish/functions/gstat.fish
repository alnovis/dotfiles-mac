function gstat --description "Show git changes summary (staged, unstaged, untracked)"
    argparse 'h/help' 'no-color' 'stat=' -- $argv; or return 1

    if set -q _flag_help
        echo "Usage: gstat [OPTIONS]"
        echo ""
        echo "Show git changes summary (staged, unstaged, untracked)."
        echo ""
        echo "Options:"
        echo "      --stat=N     Set stat output width (default: terminal width)"
        echo "      --no-color   Disable colored output"
        echo "  -h, --help       Show this help"
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
    set -l stat_flag --stat
    if set -q _flag_stat
        set stat_flag --stat=$_flag_stat
    else if test -n "$COLUMNS"
        set stat_flag --stat=$COLUMNS
    end
    set -l staged (git diff --cached $color_flag $stat_flag | string collect)
    set -l unstaged (git diff $color_flag $stat_flag | string collect)
    set -l untracked (git ls-files --others --exclude-standard)

    if test -z "$staged" -a -z "$unstaged" -a -z "$untracked"
        echo "Repository: $repo_name ($branch)"
        echo "Clean — no changes"
        return 0
    end

    echo "Repository: $repo_name ($branch)"

    if test -n "$staged"
        set_color green
        echo "Staged:"
        set_color normal
        echo "$staged"
    end

    if test -n "$unstaged"
        set_color yellow
        echo "Unstaged:"
        set_color normal
        echo "$unstaged"
    end

    set -l untracked_lines 0
    if test -n "$untracked"
        set_color cyan
        echo "Untracked:"
        set_color normal
        for f in $untracked
            set -l lines (wc -l <$f 2>/dev/null | string trim)
            if test -n "$lines" -a "$lines" -gt 0
                echo "  $f ($lines lines)"
                set untracked_lines (math $untracked_lines + $lines)
            else
                echo "  $f"
            end
        end
    end

    # Summary
    set -l staged_nums (git diff --cached --numstat | string match -rv '^\s*$')
    set -l unstaged_nums (git diff --numstat | string match -rv '^\s*$')
    set -l total_add 0
    set -l total_del 0
    set -l total_files 0

    for line in $staged_nums $unstaged_nums
        set -l parts (string split \t $line)
        if test "$parts[1]" != "-"
            set total_add (math $total_add + $parts[1])
            set total_del (math $total_del + $parts[2])
        end
        set total_files (math $total_files + 1)
    end

    set -l untracked_count (count $untracked)

    echo "---"
    set -l summary
    if test $total_files -gt 0
        set -a summary "$total_files changed"
    end
    if test $untracked_count -gt 0
        set -a summary "$untracked_count untracked"
    end
    set -l total_ins (math $total_add + $untracked_lines)
    if test $total_ins -gt 0
        set -a summary (set_color green)"+$total_ins"(set_color normal)
    end
    if test $total_del -gt 0
        set -a summary (set_color red)"-$total_del"(set_color normal)
    end
    echo (string join ", " $summary)
end
