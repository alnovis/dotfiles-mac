function gfresh --description "Fetch and rebase current branch onto base branch"
    set -l repo_root (git rev-parse --show-toplevel 2>/dev/null)
    if test $status -ne 0
        echo "Not a git repository"
        return 1
    end

    set -l repo_name (basename $repo_root)
    set -l branch (git branch --show-current)

    # Determine base branch: argument or auto-detect
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
        echo "No base branch found, specify manually: gfresh <branch>"
        return 1
    end

    if test "$branch" = "$base"
        echo "Already on $base, use 'git pull --rebase' instead"
        return 1
    end

    echo "Repository: $repo_name ($branch)"
    set_color cyan
    echo "Rebase onto: $base"
    set_color normal

    # Check for uncommitted changes
    if not git diff --quiet; or not git diff --cached --quiet
        set_color yellow
        echo "Stashing uncommitted changes..."
        set_color normal
        git stash push -m "gfresh: auto-stash"
        set -l stashed 1
    end

    echo "Fetching..."
    git fetch --all --prune 2>&1 | string match -rv '^\s*$'

    echo "Rebasing $branch onto origin/$base..."
    if not git rebase origin/$base
        set_color red
        echo "---"
        echo "Rebase conflict — resolve manually, then 'git rebase --continue'"
        set_color normal
        return 1
    end

    if set -q stashed
        set_color yellow
        echo "Restoring stashed changes..."
        set_color normal
        git stash pop
    end

    echo "---"
    set -l ahead (git rev-list --count origin/$base..HEAD)
    set_color green
    echo "Up to date — $ahead commit(s) ahead of $base"
    set_color normal
end
