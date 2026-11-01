function gclean --description "Delete local branches already merged into base"
    if contains -- --help $argv; or contains -- -h $argv
        echo "Usage: gclean"
        echo ""
        echo "Delete local branches already merged into base branch."
        echo "Auto-detects base (main/master/develop). Asks for confirmation."
        echo "Runs 'git fetch --prune' before checking."
        return 0
    end

    set -l repo_root (git rev-parse --show-toplevel 2>/dev/null)
    if test $status -ne 0
        echo "Not a git repository"
        return 1
    end

    set -l repo_name (basename $repo_root)
    set -l branch (git branch --show-current)

    # Determine base branch
    set -l base main
    if not git show-ref --verify --quiet refs/heads/main
        if git show-ref --verify --quiet refs/heads/master
            set base master
        else if git show-ref --verify --quiet refs/heads/develop
            set base develop
        end
    end

    git fetch --prune 2>/dev/null

    # `*` is the current branch, `+` one checked out in another worktree — neither can be deleted
    set -l merged (git branch --merged $base | string trim | string match -rv "^[*+]|^\\s*($base|master|main|develop)\$")

    echo "Repository: $repo_name ($branch)"
    echo "Base: $base"

    if test -z "$merged"
        echo "---"
        echo "Clean — no merged branches to delete"
        return 0
    end

    set_color yellow
    echo "Merged branches:"
    set_color normal
    for b in $merged
        echo "  $b"
    end

    read -l -P "Delete these branches? (y/N) " confirm
    if test "$confirm" != y -a "$confirm" != Y
        echo "Aborted"
        return 1
    end

    set -l count 0
    set -l failed
    for b in $merged
        if git branch -d $b >/dev/null 2>&1
            set count (math $count + 1)
        else
            set -a failed $b
        end
    end

    echo "---"
    set_color green
    echo "$count branch(es) deleted"
    set_color normal
    if test (count $failed) -gt 0
        set_color red
        echo "Not deleted: $failed"
        set_color normal
        return 1
    end
end
