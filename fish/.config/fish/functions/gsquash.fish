function gsquash --description "Squash commits: reset --soft (default) or merge --squash"
    argparse 'h/help' 'no-color' 'm/merge' -- $argv; or return 1

    if set -q _flag_help
        echo "Usage: gsquash [OPTIONS] [BASE|BRANCH] [MESSAGE]"
        echo ""
        echo "Squash commits into one. Two modes:"
        echo ""
        echo "  Default (reset --soft):"
        echo "    Squash all commits on current branch vs base."
        echo "    gsquash [BASE] [MESSAGE]"
        echo ""
        echo "  Merge (--merge):"
        echo "    Merge another branch into current as one commit."
        echo "    gsquash --merge <branch> [MESSAGE]"
        echo ""
        echo "Options:"
        echo "  -m, --merge      Use merge --squash mode"
        echo "      --no-color   Disable colored output"
        echo "  -h, --help       Show this help"
        echo ""
        echo "Examples:"
        echo "  gsquash                                Interactive, auto-detect base"
        echo "  gsquash develop \"RF-123 feat\"           Squash onto develop"
        echo "  gsquash -m feature/RF-123 \"RF-123 feat\" Merge feature branch in"
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

    # Check for uncommitted changes
    if not git diff --quiet; or not git diff --cached --quiet
        echo "Repository: $repo_name ($branch)"
        set_color red
        echo "Error: uncommitted changes — commit or stash first"
        set_color normal
        return 1
    end

    if set -q _flag_merge
        _gsquash_merge $argv
    else
        _gsquash_reset $argv
    end
end

# --- Mode 1: reset --soft (squash current branch onto base) ---
function _gsquash_reset
    # Parse positional args: [BASE] [MESSAGE]
    set -l base
    set -l msg
    if test (count $argv) -ge 1
        if git show-ref --verify --quiet refs/heads/$argv[1]
            set base $argv[1]
            if test (count $argv) -ge 2
                set msg $argv[2]
            end
        else
            set msg $argv[1]
        end
    end

    # Auto-detect base
    if test -z "$base"
        if git show-ref --verify --quiet refs/heads/develop
            set base develop
        else if git show-ref --verify --quiet refs/heads/main
            set base main
        else if git show-ref --verify --quiet refs/heads/master
            set base master
        else
            echo "No base branch found, specify manually: gsquash <branch>"
            return 1
        end
    end

    set -l repo_root (git rev-parse --show-toplevel 2>/dev/null)
    set -l repo_name (basename $repo_root)
    set -l branch (git branch --show-current)

    if test "$branch" = "$base"
        echo "Repository: $repo_name ($branch)"
        set_color red
        echo "Error: cannot squash — already on $base"
        set_color normal
        return 1
    end

    # Find merge base
    set -l merge_base (git merge-base origin/$base HEAD 2>/dev/null)
    if test -z "$merge_base"
        set merge_base (git merge-base $base HEAD 2>/dev/null)
        if test -z "$merge_base"
            set_color red
            echo "Error: cannot find common ancestor with $base"
            set_color normal
            return 1
        end
    end

    set -l commits (git rev-list --count $merge_base..HEAD)
    if test "$commits" -eq 0
        echo "Repository: $repo_name ($branch)"
        echo "No commits to squash"
        return 0
    end

    if test "$commits" -eq 1
        echo "Repository: $repo_name ($branch)"
        echo "Only 1 commit ahead of $base — nothing to squash"
        return 0
    end

    # Show overview
    echo "Repository: $repo_name ($branch)"
    set_color cyan
    echo "Base: $base ($commits commits to squash)"
    set_color normal

    echo ""
    set_color green
    echo "Commits:"
    set_color normal
    git log --oneline $color_flag $merge_base..HEAD | while read -l line
        echo "  $line"
    end

    # Diff stat
    set -l stat_flag --stat
    if set -q _flag_stat
        set stat_flag --stat=$_flag_stat
    else if test -n "$COLUMNS"
        set stat_flag --stat=$COLUMNS
    end

    echo ""
    set_color yellow
    echo "Files:"
    set_color normal
    set -l diff_stat (git diff $color_flag $stat_flag $merge_base..HEAD | string collect)
    if test -n "$diff_stat"
        echo "$diff_stat"
    end

    # Summary stats
    set -l nums (git diff --numstat $merge_base..HEAD | string match -rv '^\s*$')
    set -l total_add 0
    set -l total_del 0
    set -l total_files 0
    for line in $nums
        set -l parts (string split \t $line)
        if test "$parts[1]" != "-"
            set total_add (math $total_add + $parts[1])
            set total_del (math $total_del + $parts[2])
        end
        set total_files (math $total_files + 1)
    end

    # Commit message
    if test -z "$msg"
        echo ""
        read -l -P "Commit message: " msg
        if test -z "$msg"
            echo "Aborted"
            return 1
        end
    end

    echo ""
    read -l -P "Squash $commits commits into one? (y/N) " confirm
    if test "$confirm" != y -a "$confirm" != Y
        echo "Aborted"
        return 1
    end

    # Save current HEAD for rollback
    set -l old_head (git rev-parse HEAD)

    # Squash
    if not git reset --soft $merge_base
        set_color red
        echo "Error: reset failed"
        set_color normal
        return 1
    end

    if not git commit -m "$msg"
        set_color red
        echo "Error: commit failed — restoring previous state"
        set_color normal
        git reset --soft $old_head
        return 1
    end

    echo "---"
    set_color green
    echo "Squashed $commits commits into:"
    set_color yellow
    echo "$msg"
    set_color normal
end

# --- Mode 3: merge --squash (merge another branch into current) ---
function _gsquash_merge
    set -l source_branch
    set -l msg

    if test (count $argv) -ge 1
        set source_branch $argv[1]
        if test (count $argv) -ge 2
            set msg $argv[2]
        end
    end

    set -l repo_root (git rev-parse --show-toplevel 2>/dev/null)
    set -l repo_name (basename $repo_root)
    set -l branch (git branch --show-current)

    if test -z "$source_branch"
        echo "Repository: $repo_name ($branch)"
        set_color red
        echo "Error: specify branch to merge: gsquash --merge <branch>"
        set_color normal
        return 1
    end

    # Check source branch exists
    if not git show-ref --verify --quiet refs/heads/$source_branch
        # Try remote
        if not git show-ref --verify --quiet refs/remotes/origin/$source_branch
            set_color red
            echo "Error: branch '$source_branch' not found"
            set_color normal
            return 1
        end
    end

    if test "$branch" = "$source_branch"
        set_color red
        echo "Error: cannot merge branch into itself"
        set_color normal
        return 1
    end

    # Show what we're merging
    set -l merge_base (git merge-base HEAD $source_branch 2>/dev/null)
    set -l commits (git rev-list --count $merge_base..$source_branch 2>/dev/null; or echo 0)

    echo "Repository: $repo_name ($branch)"
    set_color cyan
    echo "Merge: $source_branch → $branch ($commits commit(s))"
    set_color normal

    if test "$commits" -eq 0
        echo "---"
        echo "Nothing to merge — $source_branch is up to date"
        return 0
    end

    echo ""
    set_color green
    echo "Commits from $source_branch:"
    set_color normal
    git log --oneline $color_flag $merge_base..$source_branch | while read -l line
        echo "  $line"
    end

    # Diff stat
    set -l stat_flag --stat
    if test -n "$COLUMNS"
        set stat_flag --stat=$COLUMNS
    end

    echo ""
    set_color yellow
    echo "Files:"
    set_color normal
    set -l diff_stat (git diff $color_flag $stat_flag $merge_base..$source_branch | string collect)
    if test -n "$diff_stat"
        echo "$diff_stat"
    end

    # Summary stats
    set -l nums (git diff --numstat $merge_base..$source_branch | string match -rv '^\s*$')
    set -l total_add 0
    set -l total_del 0
    set -l total_files 0
    for line in $nums
        set -l parts (string split \t $line)
        if test "$parts[1]" != "-"
            set total_add (math $total_add + $parts[1])
            set total_del (math $total_del + $parts[2])
        end
        set total_files (math $total_files + 1)
    end
    echo $stat_summary

    # Commit message
    if test -z "$msg"
        echo ""
        read -l -P "Commit message: " msg
        if test -z "$msg"
            echo "Aborted"
            return 1
        end
    end

    echo ""
    read -l -P "Merge-squash $source_branch into $branch? (y/N) " confirm
    if test "$confirm" != y -a "$confirm" != Y
        echo "Aborted"
        return 1
    end

    # Merge squash
    if not git merge --squash $source_branch
        set_color red
        echo "Error: merge conflict — resolve manually, then 'git commit'"
        set_color normal
        return 1
    end

    if not git commit -m "$msg"
        set_color red
        echo "Error: commit failed"
        set_color normal
        return 1
    end

    echo "---"
    set_color green
    echo "Merged $source_branch into $branch:"
    set_color yellow
    echo "$msg"
    set_color normal
end
