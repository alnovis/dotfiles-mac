function gunwip --description "Undo last WIP commit, keep changes unstaged"
    if contains -- --help $argv; or contains -- -h $argv
        echo "Usage: gunwip"
        echo ""
        echo "Undo last WIP commit, keep changes unstaged."
        echo "Only works if last commit starts with 'WIP:'."
        return 0
    end

    set -l repo_root (git rev-parse --show-toplevel 2>/dev/null)
    if test $status -ne 0
        echo "Not a git repository"
        return 1
    end

    set -l repo_name (basename $repo_root)
    set -l branch (git branch --show-current)
    set -l last_msg (git log --format=%s -1)

    if not string match -q "WIP:*" "$last_msg"
        echo "Repository: $repo_name ($branch)"
        set_color red
        echo "Last commit is not a WIP: $last_msg"
        set_color normal
        return 1
    end

    git reset HEAD~1

    echo "Repository: $repo_name ($branch)"
    echo "---"
    set_color green
    echo "WIP undone — changes restored"
    set_color normal
end
