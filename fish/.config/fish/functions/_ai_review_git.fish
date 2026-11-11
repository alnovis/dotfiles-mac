function _ai_review_git --description "AI review of git changes (branch, last N, or specific commit)"
    # Called by _ai_review dispatcher after mode detection.
    argparse 'h/help' 'model=' 'provider=' 'file=' 'brief' 'lang=' 'lang-all=' 'last=?' 'commit=' 'o/output=' 'lens=' 'no-lens' 'max-lines=' 'context-lines=' 'agentic' 'no-think' 'dry-run' \
             'verify' 'no-verify' 'verify-provider=' 'verify-model=' 'verify-output=' 'verify-runs=' 'verify-context=' 'verify-think=' 'comments' 'comments-lang=' 'runs=' 'parallel' 'no-parallel' -- $argv; or return 1
    # Lenses: --lens, else review_lens from the project's (or the global) config; --no-lens: none
    if set -q _flag_lens; and set -q _flag_no_lens
        echo "Error: --lens and --no-lens exclude each other" >&2
        return 1
    end
    set -l lens_origin --lens
    set -l lc (_ai_review_lens_choice "$_flag_lens" "$(set -q _flag_no_lens; and echo 1)" | string split \t)
    if test -n "$lc[1]"
        set _flag_lens $lc[1]
        set lens_origin $lc[2]
    end
    # A language for the comments means comments
    set -q _flag_comments_lang; and set -l _flag_comments 1
    # Quoted: an empty (…) would vanish and shift the arguments
    _ai_review_comments_check "$(set -q _flag_comments; and echo 1)" "$(set -q _flag_brief; and echo 1)" \
        "$(set -q _flag_no_verify; and echo 1)" "$_flag_output"; or return 1

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

    # How many review runs, and how they go (scoped config, see _ai_review_setting)
    set -l plan (_ai_review_runs_plan $provider "$model" "$_flag_runs" "$(set -q _flag_parallel; and echo 1)" \
        "$(set -q _flag_no_parallel; and echo 1)" "$(set -q _flag_brief; and echo 1)" "$(set -q _flag_no_verify; and echo 1)")
    or return 1
    set plan (string split \t -- $plan)
    set -l runs $plan[1]

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
    # With --commit or --last there is no base, so a lone positional is the custom prompt:
    # "ai review --last 2 \"focus on X\"" took the text as a base and dropped it. A ref there
    # is a base given by habit, ignored as before.
    if test -n "$commit_sha"; or test $last_n -gt 0
        if test (count $argv) -eq 1; and not git rev-parse --verify -q "$argv[1]^{commit}" >/dev/null 2>&1
            set custom_prompt $argv[1]
        end
        set base ""
    else if test -n "$base"
        # A base that is no ref is a prompt in the wrong place: "ai review \"focus on X\""
        if not git rev-parse --verify -q "$base^{commit}" >/dev/null 2>&1
            and not git rev-parse --verify -q "origin/$base^{commit}" >/dev/null 2>&1
            set_color red
            echo "Error: '$base' is not a branch or commit. A custom prompt goes after the base: ai review BASE \"text\", or with --last / --commit"
            set_color normal
            return 1
        end
    end

    # Get diff based on mode. $range drives --stat / --name-status; $tip is the
    # commit whose file contents we read for the "full changed files" context.
    set -l diff_content
    # What is reviewed, for the header: a key, then its value lines
    set -l header_info
    set -l range
    set -l tip

    if test -n "$commit_sha"
        # SHA, A..B or SHA1,SHA2,… — validated as one contiguous, linear change
        set -l resolved (_ai_review_commit_range $commit_sha 2>&1)
        if test $status -ne 0
            set_color red
            printf '%s\n' $resolved
            set_color normal
            return 1
        end
        set range $resolved[1]
        set tip $resolved[2]
        set -l commits $resolved[3..]
        if test -n "$file_filter"
            set diff_content (git diff $range -- $file_filter | string collect)
        else
            set diff_content (git diff $range | string collect)
        end
        if test (count $commits) -eq 1
            set header_info commit $commits[1]
        else
            set header_info commits (count $commits)" ($range)" $commits
        end

    else if test $last_n -gt 0
        set range "HEAD~$last_n..HEAD"
        set tip HEAD
        if test -n "$file_filter"
            set diff_content (git diff HEAD~$last_n..HEAD -- $file_filter | string collect)
        else
            set diff_content (git diff HEAD~$last_n..HEAD | string collect)
        end
        set header_info last "$last_n commit(s) on $branch"

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
            set diff_content (git diff $merge_base..HEAD -- $file_filter | string collect)
        else
            set diff_content (git diff $merge_base..HEAD | string collect)
        end
        set header_info base "$base ($commits commit(s))"
    end

    if test -z "$diff_content"
        echo "No changes to review"
        return 0
    end

    # Cap diff size (override with --max-lines)
    set -l diff_header "Diff:"
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
        set diff_content (echo "$diff_content" | head -n $max_lines | string collect)
        # Said in the prompt too: the model saw a diff that stops mid-hunk and took the
        # missing rest for code the change removed
        set diff_header "Diff (cut at $max_lines of $diff_lines lines: the rest of the change is not shown, do not review what is missing from it):"
    end

    # Header: the same blocks as the stages and the Saved list (_ai_ui_heading, _ai_ui_kv)
    # A detached HEAD (a worktree at a commit) has no branch: no empty "()"
    if test -n "$branch"
        _ai_ui_heading Review "$repo_name ($branch)"
    else
        _ai_ui_heading Review $repo_name
    end
    _ai_ui_kv $header_info[1] $header_info[2]
    for v in $header_info[3..]
        _ai_ui_kv "" $v
    end
    test -n "$file_filter"; and _ai_ui_kv file $file_filter
    _ai_ui_kv provider $provider
    test -n "$model"; and _ai_ui_kv model $model
    if set -q _flag_lens
        if set -q _flag_brief
            set_color yellow
            _ai_ui_kv lens "$_flag_lens (ignored — --brief mode)"
            set_color normal
        else
            set -l from ""
            test "$lens_origin" != --lens; and set from " ($lens_origin)"
            _ai_ui_kv lens "$_flag_lens$from"
        end
    end
    if _ai_verify_wanted "$(begin; set -q _flag_verify; or set -q _flag_comments; or set -q _flag_verify_runs; or set -q _flag_verify_context; or test $runs -gt 1; end; and echo 1)" "$(set -q _flag_no_verify; and echo 1)"
        if set -q _flag_brief
            set_color yellow
            _ai_ui_kv verify "requested (ignored — --brief mode)"
            set_color normal
        else
            # As the verify flow resolves it: flag > config verify_provider > review provider
            set -l vp $_flag_verify_provider
            test -z "$vp"; and set vp (_ai_config_read verify_provider 2>/dev/null)
            test -z "$vp"; and set vp "$provider"
            _ai_ui_kv verify "on ($vp)"
            set -q _flag_comments; and _ai_ui_kv comments "on (MR line comments from the verdicts$(set -q _flag_comments_lang; and echo ", in "(_ai_lang_name $_flag_comments_lang)))"
            test $runs -gt 1; and _ai_ui_kv runs "$runs ($plan[3])"
        end
    end
    test -n "$lang"; and _ai_ui_kv language (_ai_lang_name $lang)
    test -n "$output"; and _ai_ui_kv output $output

    # Diffstat preflight — always show what's under review (to stderr, keeps the
    # report on stdout clean).
    if test -n "$range"
        _ai_ui_heading Changes $range >&2
        _ai_review_diffstat $range $file_filter >&2
    end

    # Level 2 — embed full content of changed files so a single-shot model sees
    # whole files (the class, the pom/toml), not just diff hunks. Skipped for
    # --agentic (the model explores the repo itself) and --brief.
    set -l context_block ""
    set -l ctx_budget (_ai_review_context_budget git $_flag_context_lines); or return 1

    if not set -q _flag_brief; and not set -q _flag_agentic; and test $ctx_budget -gt 0
        set -l files
        set -l window 0
        for row in (_ai_review_changed_files "$range" "$tip" "$file_filter")
            set -l parts (string split \t -- $row)
            set window (math $window + $parts[1])
            set -a files $parts[2]
        end

        if test (count $files) -gt 0
            _ai_ui_kv context "$window lines across "(count $files)" files (budget $ctx_budget)" >&2

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
                _ai_ui_kv note "changed files ($window lines) exceed budget ($ctx_budget) — using diff-only. Pass --context-lines $window (or set config key context_lines) to embed all." >&2
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
    # The section headings are structure, not prose: findings are numbered by them
    # (_ai_review_number_findings), so they stay in English in any language
    set -l keep ""
    test "$lang_full" != English; and not set -q _flag_brief; and set keep " Keep the section headings as the format below writes them, in English: tools read them."
    if test -n "$lang"
        if test $lang_all -eq 1
            set lang_prefix "IMPORTANT: You MUST write your ENTIRE response in $lang_full, including your thinking/reasoning process. All text must be in $lang_full.$keep

"
            set lang_suffix "

REMINDER: Write EVERYTHING in $lang_full, including thinking."
        else
            set lang_prefix "IMPORTANT: Write your final response in $lang_full. You may think in English, but the output must be in $lang_full.$keep

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

$diff_header
$diff_content"
    else
        # Load template (overridable); fallback to minimal default
        set -l template_file ~/.config/fish/prompts/meta-review-diff.md
        set -l base
        if test -f $template_file
            set base (_ai_review_template $template_file (_ai_review_prompt_mode $provider))
        else
            set base "You are a senior code reviewer. Review this git diff. Provide: a 2-3 sentence summary, then issues by severity (critical/important/nits), then notes on tests and removed code. Cite file:line verbatim. If no issues, say 'No issues found.' and stop."
        end

        # Security lens(es)
        set -l lens_suffix ""
        if set -q _flag_lens
            # Validated outside (…): stderr there skips the caller's redirect
            _ai_review_lens $_flag_lens >/dev/null; or return 1
            set -l lens_block (_ai_review_lens $_flag_lens | string collect)
            set lens_suffix "

$lens_block"
        end

        set prompt "$lang_prefix$base$lens_suffix$custom_suffix$lang_suffix

$diff_header
$diff_content"
        if test -n "$context_block"
            set prompt "$prompt

$context_block"
        end
    end

    # Verify runs only for the detailed (non-brief) review.
    # --comments needs the verdicts, so it turns verify on.
    set -l do_verify 0
    if not set -q _flag_brief
        if _ai_verify_wanted "$(begin; set -q _flag_verify; or set -q _flag_comments; or set -q _flag_verify_runs; or set -q _flag_verify_context; or test $runs -gt 1; end; and echo 1)" "$(set -q _flag_no_verify; and echo 1)"
            set do_verify 1
        end
    end

    if test $do_verify -eq 1
        set -l p1file (mktemp)
        printf '%s' "$prompt" >$p1file
        set -l flow_args --prompt-file $p1file --provider $provider --workdir $repo_root
        set -q _flag_comments; and set -a flow_args --comments --range $range
        set -a flow_args --runs $runs --parallel-mode $plan[2]
        test -n "$model"; and set -a flow_args --model $model
        test -n "$output"; and set -a flow_args --output $output
        set -q _flag_dry_run; and set -a flow_args --dry-run
        test -n "$lang"; and set -a flow_args --lang (_ai_lang_name $lang)
        set -q _flag_comments_lang; and set -a flow_args --comments-lang (_ai_lang_name $_flag_comments_lang)
        set -q _flag_verify_provider; and set -a flow_args --verify-provider $_flag_verify_provider
        set -q _flag_verify_model; and set -a flow_args --verify-model $_flag_verify_model
        set -q _flag_verify_output; and set -a flow_args --verify-output $_flag_verify_output
        set -q _flag_verify_runs; and set -a flow_args --verify-runs $_flag_verify_runs
        set -q _flag_verify_context; and set -a flow_args --verify-context $_flag_verify_context
        set -q _flag_verify_think; and set -a flow_args --verify-think $_flag_verify_think
        set -q _flag_lens; and set -a flow_args --lens $_flag_lens
        set -q _flag_agentic; and set -a flow_args --agentic
        set -q _flag_no_think; and set -a flow_args --no-think
        # The verifier gets the code pass 1 saw: the diff, plus the full changed files when
        # they were embedded — a finding citing a line outside the hunks needs them.
        set -l diff_tmp (mktemp)
        printf '%s' "$diff_content" >$diff_tmp
        test -n "$context_block"; and printf '\n\n%s' "$context_block" >>$diff_tmp
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
        set -q _flag_agentic; and set -a provider_args --agentic --skill ai-review
        set -q _flag_no_think; and set -a provider_args --no-think
        echo "$prompt" | _ai_run_watched --heading --label "[1/1] $lbl" --output $output --dest $output -- $provider_args
    else
        # Streaming to terminal (or dry-run): output is visible, no spinner needed.
        set -l provider_args --provider $provider
        if test -n "$model"
            set -a provider_args --model $model
        end
        set -q _flag_dry_run; and set -a provider_args --dry-run
        set -q _flag_agentic; and set -a provider_args --agentic --skill ai-review
        set -q _flag_no_think; and set -a provider_args --no-think
        set -l t0 (date +%s)
        echo "$prompt" | _ai_run $provider_args
        set -q _flag_dry_run; or printf '\n  done | %ds\n' (math (date +%s) - $t0) >&2
    end

    # Verify mode reports its own two files (review + verify) inside the flow; only
    # the single-file (non-verify) path reports here.
    if test $do_verify -eq 0; and test -n "$output"; and not set -q _flag_dry_run
        if test -s "$output"
            _ai_ui_heading Saved
            _ai_ui_kv review $output
        else
            set_color red
            echo "No output written — $output is empty. The model returned nothing (interrupted stream, or context/size issue). Try again, or --context-lines 0 for a smaller prompt." >&2
            set_color normal
            return 1
        end
    end
end
