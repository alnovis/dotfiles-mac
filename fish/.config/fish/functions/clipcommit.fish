function clipcommit --description "Git commit with trimmed clipboard as message"
    argparse 'h/help' 'y/yes' 'a/amend' 'p/push' 'd/diff' 'e/edit' 'no-color' -- $argv; or return 1

    if set -q _flag_help
        echo "Usage: clipcommit [OPTIONS]"
        echo ""
        echo "Git commit using clipboard content as commit message."
        echo ""
        echo "Options:"
        echo "  -y, --yes        Skip confirmation prompt"
        echo "  -a, --amend      Amend previous commit"
        echo "  -p, --push       Push to remote after commit"
        echo "  -d, --diff       Show full diff before committing"
        echo "  -e, --edit       Edit commit message in nvim before committing"
        echo "      --no-color   Disable colored stat output"
        echo "  -h, --help       Show this help"
        return 0
    end

    set -l color_flag --color=always
    if set -q _flag_no_color
        set color_flag --color=never
    end

    set msg (pbpaste | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | string collect)
    if test -z "$msg"
        echo "Clipboard is empty"
        return 1
    end

    # Edit message in nvim
    if set -q _flag_edit
        set -l tmpfile (mktemp /tmp/clipcommit.XXXXXX)
        echo "$msg" >$tmpfile
        nvim $tmpfile
        set msg (cat $tmpfile | string collect)
        rm -f $tmpfile
        if test -z "$msg"
            echo "Empty message after edit, aborted"
            return 1
        end
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

    # Warn about unstaged changes
    set -l unstaged_files (git diff --name-only)
    if test -n "$unstaged_files"
        set_color yellow
        echo "Warning: unstaged changes in:"
        for f in $unstaged_files
            echo "  $f"
        end
        set_color normal
        echo ""
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

    # Show full diff
    if set -q _flag_diff
        set -l diff_lines (git diff --cached | wc -l | string trim)
        set -l max_inline 80
        echo ""
        if test $diff_lines -gt $max_inline
            git diff --cached --color=always | bat --style=plain
        else
            git diff --cached --color=always
        end
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

    # Push after commit
    if set -q _flag_push
        set -l remote (git remote)
        if test -n "$remote"
            git push $remote $branch
        else
            echo "No remote configured, skipping push"
        end
    end
end
