function clipcommit --description "Git commit with trimmed clipboard as message"
    argparse 'y/yes' -- $argv; or return 1

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
    set -l staged (git diff --cached --stat)

    if test -z "$staged"
        echo "Nothing staged to commit"
        return 1
    end

    echo "Repository: $repo_name ($branch)"
    echo "Staged:"
    echo "$staged"
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

    git commit -m "$msg"
end
