function gstat --description "Show git changes summary (staged, unstaged, untracked)"
    argparse 'no-color' 'stat=' -- $argv; or return 1

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

    if test -n "$untracked"
        set_color cyan
        echo "Untracked:"
        set_color normal
        for f in $untracked
            echo "  $f"
        end
    end
end
