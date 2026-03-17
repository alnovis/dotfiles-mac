function gwip --description "Quick WIP commit of all changes"
    set -l repo_root (git rev-parse --show-toplevel 2>/dev/null)
    if test $status -ne 0
        echo "Not a git repository"
        return 1
    end

    set -l repo_name (basename $repo_root)
    set -l branch (git branch --show-current)

    # Check for changes
    set -l has_staged (git diff --cached --name-only)
    set -l has_unstaged (git diff --name-only)
    set -l has_untracked (git ls-files --others --exclude-standard)

    if test -z "$has_staged" -a -z "$has_unstaged" -a -z "$has_untracked"
        echo "Repository: $repo_name ($branch)"
        echo "Nothing to commit"
        return 1
    end

    git add -A
    set -l file_count (git diff --cached --name-only | count)

    git commit -m "WIP: $branch — $(date '+%H:%M')"

    echo "Repository: $repo_name ($branch)"
    echo "---"
    set_color green
    echo "WIP saved — $file_count file(s)"
    set_color normal
    echo "Undo with: gunwip"
end
