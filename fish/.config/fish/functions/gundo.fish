function gundo --description "Soft undo last commit, keep changes staged"
    if contains -- --help $argv; or contains -- -h $argv
        echo "Usage: gundo"
        echo ""
        echo "Soft undo last commit, keep changes staged."
        echo "Asks for confirmation before undoing."
        return 0
    end

    set -l repo_root (git rev-parse --show-toplevel 2>/dev/null)
    if test $status -ne 0
        echo "Not a git repository"
        return 1
    end

    set -l repo_name (basename $repo_root)
    set -l branch (git branch --show-current)
    set -l last_commit (git log --oneline -1)

    if test -z "$last_commit"
        echo "No commits to undo"
        return 1
    end

    echo "Repository: $repo_name ($branch)"
    set_color yellow
    echo "Undo:"
    set_color normal
    echo "  $last_commit"

    read -l -P "Undo this commit? (y/N) " confirm
    if test "$confirm" != y -a "$confirm" != Y
        echo "Aborted"
        return 1
    end

    git reset --soft HEAD~1

    echo "---"
    set_color green
    echo "Commit undone, changes are staged"
    set_color normal
end
