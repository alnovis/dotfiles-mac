function clipcommit --description "Git commit with trimmed clipboard as message"
    argparse 'y/yes' 'a/amend' 'no-color' -- $argv; or return 1

    set -l color_flag --color=always
    if set -q _flag_no_color
        set color_flag --color=never
    end

    set msg (pbpaste | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | string collect)
    if test -z "$msg"
        echo "Clipboard is empty"
        return 1
    end

    # Repo info
    set -l repo_root (git rev-parse --show-toplevel 2>/dev/null)
    if test $status -ne 0
        echo "Not a git repository"
        return 1
    end
    set -l repo_name (basename $repo_root)
    set -l branch (git branch --show-current)
    set -l staged (git diff --cached $color_flag --stat=$COLUMNS | string collect)

    if set -q _flag_amend
        set -l unstaged (git diff $color_flag --stat=$COLUMNS | string collect)
        if test -z "$staged" -a -z "$unstaged"
            echo "Nothing to amend (no staged or unstaged changes)"
            return 1
        end
    else if test -z "$staged"
        echo "Nothing staged to commit"
        return 1
    end

    echo "Repository: $repo_name ($branch)"
    if set -q _flag_amend
        echo "Mode: AMEND"
        echo "Previous commit: "(git log --oneline -1)
    end
    if test -n "$staged"
        echo "Staged:"
        echo "$staged"
    end
    echo "---"
    echo "Commit message:"
    echo "$msg"
    echo "---"

    if not set -q _flag_yes
        read -l -P "Commit? (Y/n) " confirm
        if test "$confirm" = n -o "$confirm" = N
            echo "Aborted"
            return 1
        end
    end

    if set -q _flag_amend
        git commit --amend -m "$msg"
    else
        git commit -m "$msg"
    end
end
