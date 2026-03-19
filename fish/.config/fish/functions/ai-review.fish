function ai-review --description "AI code review of branch changes"
    if contains -- --help $argv; or contains -- -h $argv
        echo "Usage: ai-review [OPTIONS] [BASE]"
        echo ""
        echo "AI code review of current branch vs base branch."
        echo "Uses AI_DEFAULT_MODEL if set, otherwise deepseek-coder-v2:16b."
        echo ""
        echo "Options:"
        echo "  --model MODEL    Override model"
        echo "  --file FILE      Review only changes in specific file"
        echo "  --brief          Short summary instead of detailed review"
        echo "  -h, --help       Show this help"
        echo ""
        echo "Examples:"
        echo "  ai-review                        Review vs auto-detected base"
        echo "  ai-review develop                 Review vs develop"
        echo "  ai-review --file src/Foo.java     Review specific file"
        echo "  ai-review --brief                 Quick summary"
        echo "  ai-review --model qwen2.5-coder:32b"
        return 0
    end

    set -l repo_root (git rev-parse --show-toplevel 2>/dev/null)
    if test $status -ne 0
        echo "Not a git repository"
        return 1
    end

    set -l repo_name (basename $repo_root)
    set -l branch (git branch --show-current)

    # Parse args
    set -l model
    set -l file_filter
    set -l brief 0
    set -l base
    set -l i 1
    while test $i -le (count $argv)
        switch $argv[$i]
            case --model
                set i (math $i + 1)
                set model $argv[$i]
            case --file
                set i (math $i + 1)
                set file_filter $argv[$i]
            case --brief
                set brief 1
            case '*'
                set base $argv[$i]
        end
        set i (math $i + 1)
    end

    # Default model
    if test -z "$model"
        if set -q AI_DEFAULT_MODEL; and test -n "$AI_DEFAULT_MODEL"
            set model $AI_DEFAULT_MODEL
        else
            set model deepseek-coder-v2:16b
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
            echo "No base branch found, specify manually: ai-review <branch>"
            return 1
        end
    end

    if test "$branch" = "$base"
        echo "Already on $base, nothing to review"
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
        echo "No commits to review"
        return 0
    end

    # Get diff
    set -l diff_content
    if test -n "$file_filter"
        set diff_content (git diff $merge_base..HEAD -- $file_filter)
        if test -z "$diff_content"
            echo "No changes in $file_filter"
            return 0
        end
    else
        set diff_content (git diff $merge_base..HEAD)
    end

    # Check diff size
    set -l diff_lines (echo "$diff_content" | wc -l | string trim)
    set -l max_lines 500

    if test "$diff_lines" -gt $max_lines
        set_color yellow
        echo "Warning: diff is large ($diff_lines lines). Truncating to $max_lines lines."
        echo "Use --file to review specific files."
        set_color normal
        echo ""
        set diff_content (echo "$diff_content" | head -n $max_lines)
    end

    _ai_ensure_running; or return 1

    # Header
    echo "Repository: $repo_name ($branch)"
    set_color cyan
    echo "Base: $base ($commits commit(s))"
    set_color normal
    if test -n "$file_filter"
        set_color yellow
        echo "File: $file_filter"
        set_color normal
    end
    echo "Model: $model"
    echo "---"

    # Build prompt
    set -l prompt
    if test $brief -eq 1
        set prompt "Give a brief summary of this code change in 3-5 bullet points. Focus on what changed and potential risks. Be concise.

Diff:
$diff_content"
    else
        set prompt "You are a senior code reviewer. Review this git diff and provide:

1. **Summary**: What does this change do (2-3 sentences)
2. **Issues**: Bugs, potential problems, security concerns (if any)
3. **Suggestions**: Improvements, better approaches (if any)

Be specific, reference file names and line numbers. If the code looks good, say so.

Diff:
$diff_content"
    end

    # Run review
    echo "$prompt" | ollama run $model
end
