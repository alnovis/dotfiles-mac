function _ai_review_git --description "AI review of git changes (branch, last N, or specific commit)"
    # Called by _ai_review dispatcher after mode detection.
    argparse 'h/help' 'model=' 'provider=' 'file=' 'brief' 'lang=' 'lang-all=' 'last=?' 'commit=' 'o/output=' 'lens=' 'max-lines=' 'context-lines=' 'agentic' 'dry-run' \
             'verify' 'no-verify' 'verify-provider=' 'verify-model=' 'verify-output=' -- $argv; or return 1

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

    # Get diff based on mode. $range drives --stat / --name-status; $tip is the
    # commit whose file contents we read for the "full changed files" context.
    set -l diff_content
    set -l header_info
    set -l range
    set -l tip

    if test -n "$commit_sha"
        set -l commit_msg (git log --oneline -1 $commit_sha 2>/dev/null)
        if test -z "$commit_msg"
            set_color red
            echo "Error: commit '$commit_sha' not found"
            set_color normal
            return 1
        end
        set range "$commit_sha~1..$commit_sha"
        set tip $commit_sha
        if test -n "$file_filter"
            set diff_content (git show $commit_sha -- $file_filter)
        else
            set diff_content (git diff $commit_sha~1..$commit_sha)
        end
        set header_info "Commit: $commit_msg"

    else if test $last_n -gt 0
        set range "HEAD~$last_n..HEAD"
        set tip HEAD
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

        set range "$merge_base..HEAD"
        set tip HEAD
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

    # Cap diff size (override with --max-lines)
    set -l diff_lines (echo "$diff_content" | wc -l | string trim)
    set -l max_lines 500
    if set -q _flag_max_lines
        if string match -qr '^[0-9]+$' -- $_flag_max_lines; and test $_flag_max_lines -gt 0
            set max_lines $_flag_max_lines
        else
            set_color red
            echo "Error: --max-lines must be a positive integer" >&2
            set_color normal
            return 1
        end
    end

    if test "$diff_lines" -gt $max_lines
        set_color yellow
        echo "Warning: diff is large ($diff_lines lines). Truncating to $max_lines lines."
        echo "Use --file to review specific files, or --max-lines N to raise the cap."
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
    if set -q _flag_lens
        if set -q _flag_brief
            set_color yellow
            echo "Lens: $_flag_lens (ignored — --brief mode)"
            set_color normal
        else
            echo "Lens: $_flag_lens"
        end
    end
    if _ai_verify_wanted (set -q _flag_verify; and echo 1) (set -q _flag_no_verify; and echo 1)
        if set -q _flag_brief
            set_color yellow
            echo "Verify: requested (ignored — --brief mode)"
            set_color normal
        else
            set -l vp $_flag_verify_provider
            test -z "$vp"; and set vp "$provider"
            echo "Verify: on ($vp)"
        end
    end
    if test -n "$lang"
        echo "Language: "(_ai_lang_name $lang)
    end
    if test -n "$output"
        echo "Output: $output"
    end
    echo "---"

    # Diffstat preflight — always show what's under review (to stderr, keeps the
    # report on stdout clean).
    if test -n "$range"
        set_color cyan >&2
        echo "Changes ($range):" >&2
        set_color normal >&2
        # --no-pager: the stat goes to a tty (stderr), so git would otherwise pipe
        # it through the pager (bat/less) and block until the user quits.
        if test -n "$file_filter"
            git --no-pager diff $range --stat -- $file_filter >&2 2>/dev/null
        else
            git --no-pager diff $range --stat >&2 2>/dev/null
        end
    end

    # Level 2 — embed full content of changed files so a single-shot model sees
    # whole files (the class, the pom/toml), not just diff hunks. Skipped for
    # --agentic (the model explores the repo itself) and --brief.
    set -l context_block ""
    set -l ctx_budget 2000
    if set -q _flag_context_lines
        if string match -qr '^[0-9]+$' -- $_flag_context_lines
            set ctx_budget $_flag_context_lines
        else
            set_color red >&2
            echo "Error: --context-lines must be a non-negative integer" >&2
            set_color normal >&2
            return 1
        end
    end

    if not set -q _flag_brief; and not set -q _flag_agentic; and test $ctx_budget -gt 0
        set -l files
        set -l window 0
        for row in (_ai_review_changed_files "$range" "$tip" "$file_filter")
            set -l parts (string split \t -- $row)
            set window (math $window + $parts[1])
            set -a files $parts[2]
        end

        if test (count $files) -gt 0
            set_color cyan >&2
            echo "Context window: $window lines across "(count $files)" files (budget $ctx_budget)" >&2
            set_color normal >&2

            set -l embed 0
            if test $window -le $ctx_budget
                set embed 1
            else if isatty stdin; and isatty stderr
                set_color yellow >&2
                echo "Changed files ($window lines) exceed the context budget ($ctx_budget)." >&2
                echo "  [1] diff-only (default)    [2] embed all $window lines" >&2
                set_color normal >&2
                read -l -P "Choose [1/2]: " choice
                test "$choice" = 2; and set embed 1
            else
                set_color yellow >&2
                echo "Note: changed files ($window lines) exceed budget ($ctx_budget) — using diff-only. Pass --context-lines $window to embed all." >&2
                set_color normal >&2
            end

            if test $embed -eq 1
                set context_block (_ai_review_context_block "$tip" $files | string collect)
            end
        end
    end

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

        # Security lens(es)
        set -l lens_suffix ""
        if set -q _flag_lens
            set -l lens_block (_ai_review_lens $_flag_lens); or return 1
            set lens_suffix "

$lens_block"
        end

        set prompt "$lang_prefix$base$lens_suffix$custom_suffix$lang_suffix

Diff:
$diff_content"
        if test -n "$context_block"
            set prompt "$prompt

$context_block"
        end
    end

    # Verify runs only for the detailed (non-brief) review.
    set -l do_verify 0
    if not set -q _flag_brief
        if _ai_verify_wanted (set -q _flag_verify; and echo 1) (set -q _flag_no_verify; and echo 1)
            set do_verify 1
        end
    end

    if test $do_verify -eq 1
        set -l p1file (mktemp)
        printf '%s' "$prompt" >$p1file
        set -l flow_args --prompt-file $p1file --provider $provider --workdir $repo_root
        test -n "$model"; and set -a flow_args --model $model
        test -n "$output"; and set -a flow_args --output $output
        set -q _flag_dry_run; and set -a flow_args --dry-run
        test -n "$lang"; and set -a flow_args --lang (_ai_lang_name $lang)
        set -q _flag_verify_provider; and set -a flow_args --verify-provider $_flag_verify_provider
        set -q _flag_verify_model; and set -a flow_args --verify-model $_flag_verify_model
        set -q _flag_verify_output; and set -a flow_args --verify-output $_flag_verify_output
        set -q _flag_agentic; and set -a flow_args --agentic
        # The diff is the code context embedded for the verifier.
        set -l diff_tmp (mktemp)
        printf '%s' "$diff_content" >$diff_tmp
        set -a flow_args --code-file $diff_tmp
        _ai_review_verify_flow $flow_args
        rm -f $diff_tmp $p1file
    else if test -n "$output"; and not set -q _flag_dry_run
        # Output captured to a file → terminal is quiet, so show a live watched run.
        set -l lbl "Review - $provider"
        test -n "$model"; and set lbl "$lbl - $model"
        _ai_stage_plan "$lbl"
        set -l provider_args --provider $provider
        test -n "$model"; and set -a provider_args --model $model
        set -q _flag_agentic; and set -a provider_args --agentic
        echo "$prompt" | _ai_run_watched --label "$lbl" --output $output --dest $output -- $provider_args
    else
        # Streaming to terminal (or dry-run): output is visible, no spinner needed.
        set -l provider_args --provider $provider
        if test -n "$model"
            set -a provider_args --model $model
        end
        set -q _flag_dry_run; and set -a provider_args --dry-run
        set -q _flag_agentic; and set -a provider_args --agentic
        echo "$prompt" | _ai_run $provider_args
    end

    # Verify mode reports its own two files (review + verify) inside the flow; only
    # the single-file (non-verify) path reports here.
    if test $do_verify -eq 0; and test -n "$output"; and not set -q _flag_dry_run
        if test -s "$output"
            set_color green
            echo "Saved to: $output"
            set_color normal
        else
            set_color red
            echo "No output written — $output is empty. The model returned nothing (interrupted stream, or context/size issue). Try again, or --context-lines 0 for a smaller prompt." >&2
            set_color normal
            return 1
        end
    end
end
