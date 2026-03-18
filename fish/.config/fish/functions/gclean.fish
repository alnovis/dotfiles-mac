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

    set -l merged (git branch --merged $base | string trim | string match -rv "^\*|^\\s*($base|master|main|develop)\$")

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
    for b in $merged
        git branch -d $b 2>/dev/null
        set count (math $count + 1)
    end

    echo "---"
    set_color green
    echo "$count branch(es) deleted"
    set_color normal
end
