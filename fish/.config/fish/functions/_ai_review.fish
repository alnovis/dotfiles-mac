function _ai_review --description "AI code review of branch or commit changes"
    if contains -- --help $argv; or contains -- -h $argv
        echo "Usage: ai review [OPTIONS] [BASE]"
        echo ""
        echo "AI code review. Reviews branch vs base by default."
        echo "Uses AI_DEFAULT_MODEL if set, otherwise deepseek-coder-v2:16b."
        echo ""
        echo "Options:"
        echo "  --model MODEL    Override model"
        echo "  --file FILE      Review only changes in specific file"
        echo "  --brief          Short summary instead of detailed review"
        echo "  --lang LANG      Response language (default: en). Thinking stays in English."
        echo "  --lang-all LANG  Full response + thinking in specified language (slower)"
        echo "  --last [N]       Review last N commit(s) (default: 1)"
        echo "  --commit SHA     Review a specific commit"
        echo "  -h, --help       Show this help"
        echo ""
        echo "Examples:"
        echo "  ai review                        Review branch vs base"
        echo "  ai review develop                 Review vs develop"
        echo "  ai review --last                  Review last commit"
        echo "  ai review --last 3                Review last 3 commits"
        echo "  ai review --commit abc1234        Review specific commit"
        echo "  ai review --file src/Foo.java     Review specific file"
        echo "  ai review --brief --lang fr       Brief review in French"
        echo "  ai review --lang-all de          Full review in German (incl. thinking)"
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
    set -l lang
    set -l lang_all 0
    set -l base
    set -l last_n 0
    set -l commit_sha
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
            case --lang
                set i (math $i + 1)
                set lang $argv[$i]
            case --lang-all
                set i (math $i + 1)
                set lang $argv[$i]
                set lang_all 1
            case --last
                set last_n 1
                # Check if next arg is a number
                if test $i -lt (count $argv)
                    set -l next $argv[(math $i + 1)]
                    if string match -qr '^\d+$' $next
                        set last_n $next
                        set i (math $i + 1)
                    end
                end
            case --commit
                set i (math $i + 1)
                set commit_sha $argv[$i]
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

    # Get diff based on mode
    set -l diff_content
    set -l header_info

    if test -n "$commit_sha"
        # Specific commit
        set -l commit_msg (git log --oneline -1 $commit_sha 2>/dev/null)
        if test -z "$commit_msg"
            set_color red
            echo "Error: commit '$commit_sha' not found"
            set_color normal
            return 1
        end
        if test -n "$file_filter"
            set diff_content (git show $commit_sha -- $file_filter)
        else
            set diff_content (git diff $commit_sha~1..$commit_sha)
        end
        set header_info "Commit: $commit_msg"

    else if test $last_n -gt 0
        # Last N commits
        if test -n "$file_filter"
            set diff_content (git diff HEAD~$last_n..HEAD -- $file_filter)
        else
            set diff_content (git diff HEAD~$last_n..HEAD)
        end
        set header_info "Last $last_n commit(s) on $branch"

    else
        # Branch vs base
        if test -z "$base"
            if git show-ref --verify --quiet refs/heads/develop
                set base develop
            else if git show-ref --verify --quiet refs/heads/main
                set base main
            else if git show-ref --verify --quiet refs/heads/master
                set base master
            else
                echo "No base branch found, specify manually: ai review <branch>"
                return 1
            end
        end

        if test "$branch" = "$base"
            echo "Already on $base — use --last or --commit to review"
            return 1
        end

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

        if test -n "$file_filter"
            set diff_content (git diff $merge_base..HEAD -- $file_filter)
        else
            set diff_content (git diff $merge_base..HEAD)
        end
        set header_info "Base: $base ($commits commit(s))"
    end

    # Validate diff
    if test -z "$diff_content"
        echo "No changes to review"
        return 0
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
    echo "$header_info"
    set_color normal
    if test -n "$file_filter"
        set_color yellow
        echo "File: $file_filter"
        set_color normal
    end
    echo "Model: $model"
    if test -n "$lang"
        echo "Language: "(_ai_lang_name $lang)
    end
    echo "---"

    # Language instruction
    set -l lang_prefix ""
    set -l lang_suffix ""
    set -l lang_full (_ai_lang_name $lang)
    if test -n "$lang"
        if test $lang_all -eq 1
            set lang_prefix "IMPORTANT: You MUST write your ENTIRE response in $lang_full, including your thinking/reasoning process. All text must be in $lang_full.

"
            set lang_suffix "

REMINDER: Write EVERYTHING in $lang_full, including thinking."
        else
            set lang_prefix "IMPORTANT: Write your final response in $lang_full. You may think in English, but the output must be in $lang_full.

"
            set lang_suffix "

REMINDER: Final response must be in $lang_full."
        end
    end

    # Build prompt
    set -l prompt
    if test $brief -eq 1
        set prompt "$lang_prefix""Give a brief summary of this code change in 3-5 bullet points. Focus on what changed and potential risks. Be concise.$lang_suffix

Diff:
$diff_content"
    else
        set prompt "$lang_prefix""You are a senior code reviewer. Review this git diff and provide:

1. **Summary**: What does this change do (2-3 sentences)
2. **Issues**: Bugs, potential problems, security concerns (if any)
3. **Suggestions**: Improvements, better approaches (if any)

Be specific, reference file names and line numbers. If the code looks good, say so.$lang_suffix

Diff:
$diff_content"
    end

    # Run review
    echo "$prompt" | ollama run $model
end
