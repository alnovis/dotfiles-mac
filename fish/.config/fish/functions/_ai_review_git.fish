function _ai_review_git --description "AI review of git changes (branch, last N, or specific commit)"
    # Called by _ai_review dispatcher after mode detection.
    argparse 'h/help' 'model=' 'provider=' 'file=' 'brief' 'lang=' 'lang-all=' 'last=?' 'commit=' 'o/output=' 'dry-run' -- $argv; or return 1

    set -l repo_root (git rev-parse --show-toplevel 2>/dev/null)
    if test $status -ne 0
        echo "Not a git repository"
        return 1
    end

    set -l repo_name (basename $repo_root)
    set -l branch (git branch --show-current)

    # Resolve flags
    set -l provider
    if set -q _flag_provider
        set provider $_flag_provider
    else
        set provider (_ai_default_provider review)
    end

    set -l model $_flag_model
    if test -z "$model"
        set model (_ai_default_model review $provider)
    end

    set -l lang en
    set -l lang_all 0
    if set -q _flag_lang_all
        set lang $_flag_lang_all
        set lang_all 1
    else if set -q _flag_lang
        set lang $_flag_lang
    end

    set -l last_n 0
    if set -q _flag_last
        if test -n "$_flag_last"
            set last_n $_flag_last
        else
            set last_n 1
        end
    end

    set -l file_filter $_flag_file
    set -l commit_sha $_flag_commit
    set -l base $argv[1]
    set -l custom_prompt $argv[2]
    set -l output $_flag_output

    # Get diff based on mode
    set -l diff_content
    set -l header_info

    if test -n "$commit_sha"
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
        if test -n "$file_filter"
            set diff_content (git diff HEAD~$last_n..HEAD -- $file_filter)
        else
            set diff_content (git diff HEAD~$last_n..HEAD)
        end
        set header_info "Last $last_n commit(s) on $branch"

    else
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

    if test -z "$diff_content"
        echo "No changes to review"
        return 0
    end

    # Cap diff size
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
    echo "Provider: $provider"
    if test -n "$model"
        echo "Model: $model"
    end
    if test -n "$lang"
        echo "Language: "(_ai_lang_name $lang)
    end
    if test -n "$output"
        echo "Output: $output"
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
    set -l custom_suffix ""
    if test -n "$custom_prompt"
        set custom_suffix "

Additional instructions: $custom_prompt"
    end

    set -l prompt
    if set -q _flag_brief
        set prompt "$lang_prefix""Give a brief summary of this code change in 3-5 bullet points. Focus on what changed and potential risks. Be concise.$custom_suffix$lang_suffix

Diff:
$diff_content"
    else
        # Load template (overridable); fallback to minimal default
        set -l template_file ~/.config/fish/prompts/meta-review-diff.md
        set -l base
        if test -f $template_file
            set base (cat $template_file | string collect)
        else
            set base "You are a senior code reviewer. Review this git diff. Provide: a 2-3 sentence summary, then issues by severity (critical/important/nits), then notes on tests and removed code. Cite file:line verbatim. If no issues, say 'No issues found.' and stop."
        end
        set prompt "$lang_prefix$base$custom_suffix$lang_suffix

Diff:
$diff_content"
    end

    # Run review
    set -l provider_args --provider $provider
    if test -n "$model"
        set -a provider_args --model $model
    end
    if test -n "$output"
        set -a provider_args --output $output
    end
    set -q _flag_dry_run; and set -a provider_args --dry-run
    echo "$prompt" | _ai_run $provider_args

    if test -n "$output"; and not set -q _flag_dry_run
        set_color green
        echo "Saved to: $output"
        set_color normal
    end
end
