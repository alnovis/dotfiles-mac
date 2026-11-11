function _ai_review_verify_flow --description "Two-pass review: first-pass review, then a second-opinion verify pass"
    # Reads the assembled first-pass prompt from --prompt-file. Called only in --verify mode.
    #   --prompt-file F          file holding the assembled first-pass review prompt (required)
    #   --provider P --model M   review provider/model (also the verify fallback)
    #   --workdir DIR            repo/dir for tool-grounded verification
    #   --output FILE            write the raw review here; the verify pass goes to a
    #                            SEPARATE file (see --verify-output) so the (possibly
    #                            expensive) review is never entangled or clobbered
    #   --verify-output FILE     explicit path for the verify pass (default: derived
    #                            from --output as <base>.verify.<ext>)
    #   --lang FULL              language name
    #   --dry-run                preview both steps, invoke nothing
    #   --verify-provider P      override verify provider (default: review provider)
    #   --verify-model M         override verify model (default: per-task config)
    #   --code-file FILE         code/diff context embedded for the verifier
    #   --comments               a third stage: MR line comments from the verified findings
    #   --comments-lang FULL     language name of those comments (default: --lang)
    #   --range BASE..HEAD       the reviewed range, for anchoring those comments
    #   --runs N                 run the review N times and join them (_ai_review_runs)
    #   --parallel-mode M        parallel | sequential, for those runs
    #   --lens A,B               the review's lenses, handed to verify too
    #   --verify-runs N          verify N times, joined by majority per finding (_ai_verify_vote)
    #   --verify-context assembled  verify on the code the findings cite, read beforehand
    #   --verify-think L         how much the verifier thinks (false, low, medium, …)
    argparse 'prompt-file=' 'provider=' 'model=' 'workdir=' 'output=' 'verify-output=' 'lang=' 'dry-run' 'agentic' 'no-think' \
             'verify-provider=' 'verify-model=' 'code-file=' 'comments' 'comments-lang=' 'range=' 'runs=' 'parallel-mode=' 'lens=' 'verify-runs=' 'verify-context=' 'verify-think=' -- $argv; or return 1
    set -l runs $_flag_runs
    test -n "$runs"; or set runs 1

    if test -z "$_flag_prompt_file"; or not test -f "$_flag_prompt_file"
        echo "verify-flow: missing --prompt-file" >&2
        return 1
    end
    set -l pass1_prompt (cat $_flag_prompt_file | string collect)

    set -l provider $_flag_provider
    set -l model $_flag_model
    set -l workdir $_flag_workdir
    test -z "$workdir"; and set workdir $PWD
    set -l output $_flag_output
    set -l lang $_flag_lang
    set -l com_lang $_flag_comments_lang
    test -n "$com_lang"; or set com_lang $lang

    # Resolve verify provider: flag > verify_* config > review provider.
    set -l vprovider $_flag_verify_provider
    if test -z "$vprovider"
        set vprovider (_ai_config_read verify_provider)
        test $status -ne 0; and set vprovider ""
    end
    test -z "$vprovider"; and set vprovider $provider

    # Resolve verify model: flag > per-task config (provider-matched) > provider default.
    set -l vmodel $_flag_verify_model
    if test -z "$vmodel"
        set vmodel (_ai_default_model verify $vprovider)
    end

    # Verify runs: --verify-runs > verify_runs (scoped by the verify provider/model) > 1; in
    # parallel or in turn by the same rule as review runs (review_parallel, auto)
    # Checked outside (…) first: stderr inside it skips the caller's redirect
    _ai_verify_runs_count $vprovider "$vmodel" "$_flag_verify_runs" >/dev/null; or return 1
    set -l vr (_ai_verify_runs_count $vprovider "$vmodel" "$_flag_verify_runs" | string split \t)
    set -l vruns $vr[1]
    set -l vmode sequential
    if test $vruns -gt 1
        set -l vm (_ai_review_parallel_mode $vprovider "$vmodel" "" | string split \t)
        test -n "$vm[1]"; and set vmode $vm[1]
    end

    # Two output paths: review -> --output; verify -> --verify-output or derived.
    # Both empty => stream a combined view to the terminal.
    set -l review_out $output
    set -l verify_out
    if test -n "$review_out"
        if test -n "$_flag_verify_output"
            set verify_out $_flag_verify_output
        else
            set verify_out (_ai_verify_output_path $review_out)
        end
    end

    set -l run_args --provider $provider --workdir $workdir
    test -n "$model"; and set -a run_args --model $model
    set -q _flag_agentic; and set -a run_args --agentic --skill ai-review
    set -q _flag_no_think; and set -a run_args --no-think


    if set -q _flag_dry_run
        set_color cyan >&2; echo "--- dry-run: pass 1 (review) ---" >&2; set_color normal >&2
        test $runs -gt 1; and echo "review runs: $runs ($_flag_parallel_mode), joined under ## Run K/$runs" >&2
        printf '%s' "$pass1_prompt" | _ai_run $run_args --dry-run
        # The prompt ends without a newline: the pass 2 header goes on a line of its own
        echo
        set_color cyan >&2; echo "--- dry-run: pass 2 (verify) ---" >&2; set_color normal >&2
        set -l code_note "no code"
        if test -n "$_flag_code_file"; and test -f "$_flag_code_file"
            set code_note "code: "(count (cat $_flag_code_file))" lines"
        end
        set -l lens_note ""
        test -n "$_flag_lens"; and set lens_note " + lens(es) $_flag_lens"
        set -l ctx_note ""
        test "$_flag_verify_context" = assembled; and set ctx_note " + the code the findings cite, read from the repository; no tools"
        set -l vthink $_flag_verify_think
        test -z "$vthink"; and not set -q _flag_no_think; and set vthink (_ai_config_read verify_think 2>/dev/null)
        set -l think_note ""
        test -n "$vthink"; and set think_note " think=$vthink"
        echo "verify provider=$vprovider model=$vmodel$think_note (prompt: meta-verify.md$lens_note + first-pass findings + $code_note$ctx_note)" >&2
        test $vruns -gt 1; and echo "verify runs: $vruns ($vmode), joined by majority per finding (origin: $vr[2])" >&2
        test -n "$review_out"; and echo "would write: review -> $review_out ; verify -> $verify_out" >&2
        if set -q _flag_comments
            set_color cyan >&2; echo "--- dry-run: pass 3 (comments) ---" >&2; set_color normal >&2
            _ai_review_comments --dry-run --output $review_out --provider $vprovider --model "$vmodel" --lang "$com_lang" --range "$_flag_range"
        end
        return 0
    end

    # Comments are a third stage: the same verify model turns the verdicts into MR comments
    set -l n_stages 2
    set -q _flag_comments; and set n_stages 3
    set -l rev_label "Review - $provider"
    test $runs -gt 1; and set rev_label "Review ×$runs - $provider"
    test -n "$model"; and set rev_label "$rev_label - $model"
    set -l ver_label "Verify - $vprovider"
    test $vruns -gt 1; and set ver_label "Verify ×$vruns - $vprovider"
    test -n "$vmodel"; and set ver_label "$ver_label - $vmodel"
    set -l com_label "Comments - $vprovider"
    test -n "$vmodel"; and set com_label "$com_label - $vmodel"
    if test $n_stages -eq 3
        _ai_stage_plan "$rev_label" "$ver_label" "$com_label"
    else
        _ai_stage_plan "$rev_label" "$ver_label"
    end

    # Pass 1 — with --output the review is written DIRECTLY to its own file, so it is
    # durable the instant the pass completes (survives a verify crash / Ctrl-C). That
    # same file also feeds pass 2 as the findings source. Without --output, a temp
    # holds it for the terminal print at the end.
    set -l find_src
    set -l find_is_temp 0
    if test -n "$review_out"
        set find_src $review_out
    else
        set find_src (mktemp)
        set find_is_temp 1
    end
    set -l rev_dest $review_out
    test -z "$rev_dest"; and set rev_dest "(terminal)"

    set -l runs_ok 1
    set -l rc1 0
    set -l rev_failed
    # Stage times for the Saved block's "time" line
    set -l t0 (date +%s)
    if test $runs -gt 1
        set -g __ai_review_runs_ok 0
        _ai_review_runs --runs $runs --mode $_flag_parallel_mode --prompt-file $_flag_prompt_file \
            --output $find_src --dest $rev_dest --label "[1/$n_stages] $rev_label" -- $run_args
        set rc1 $status
        set runs_ok $__ai_review_runs_ok
        set rev_failed $__ai_runs_failed
    else
        printf '%s' "$pass1_prompt" | _ai_run_watched --heading --label "[1/$n_stages] $rev_label" --output $find_src --dest $rev_dest -- $run_args
        set rc1 $status
    end

    if test $rc1 -ne 0; or not test -s $find_src
        set -l why "$__ai_last_failure"
        test $runs -gt 1; and set why "no run answered"
        echo "  Review pass produced no output (provider=$provider)"(test -n "$why"; and echo ": $why")". Aborting before verify." >&2
        for f in $rev_failed
            echo "    $f" >&2
        end
        test $find_is_temp -eq 1; and rm -f $find_src
        return 1
    end

    # Not empty is not enough: a model that meant to explore first can stop after one
    # sentence ("I'll examine the key files…"). Every review format has a severity
    # section or the clean verdict — without one there is nothing to verify.
    if not grep -qiE 'critical|important|no issues found' $find_src
        echo "  Review pass does not look like a review (no Critical/Important section, no \"No issues found\") — skipping verify. It wrote:" >&2
        head -5 $find_src | sed 's/^/    | /' >&2
        test $find_is_temp -eq 1; and rm -f $find_src
        return 1
    end

    # Findings get numbers [F1], [F2]… in the saved review: verify keys its verdicts by them
    set -l numbered (mktemp)
    _ai_review_number_findings <$find_src >$numbered; and mv $numbered $find_src
    rm -f $numbered

    # Pass 2 — verify.
    set -l vargs --provider $vprovider --workdir $workdir --findings-file $find_src
    test -n "$vmodel"; and set -a vargs --model $vmodel
    test -n "$lang"; and set -a vargs --lang $lang
    test -n "$_flag_code_file"; and set -a vargs --code-file $_flag_code_file
    test -n "$_flag_lens"; and set -a vargs --lens $_flag_lens
    set -q _flag_verify_context; and set -a vargs --context $_flag_verify_context
    set -q _flag_agentic; and set -a vargs --agentic
    set -q _flag_no_think; and set -a vargs --no-think
    set -q _flag_verify_think; and set -a vargs --think-level $_flag_verify_think

    set -l ver_target
    set -l ver_is_temp 0
    if test -n "$verify_out"
        set ver_target $verify_out
    else
        set ver_target (mktemp)
        set ver_is_temp 1
    end
    set -l ver_dest $verify_out
    test -z "$ver_dest"; and set ver_dest "(terminal)"

    set -l t_rev (date +%s)
    set -e __ai_verify_run_files
    set -e __ai_runs_failed
    _ai_review_verify $vargs --runs $vruns --mode $vmode --output $ver_target --label "[2/$n_stages] $ver_label" --dest $ver_dest
    set -l rc2 $status
    set -l t_ver (date +%s)
    # Kept now: the comments stage below would overwrite them
    set -l ver_why "$__ai_last_failure"
    set -l ver_failed $__ai_runs_failed

    # Stage 3 — comments, only over a verify pass that produced verdicts
    set -l rc3 0
    set -l com_note
    if set -q _flag_comments; and test -n "$review_out"
        if test -s "$ver_target"
            _ai_review_comments --findings $find_src --verdicts $ver_target --output $review_out \
                --provider $vprovider --model "$vmodel" --lang "$com_lang" --range "$_flag_range" --root $workdir \
                --runs $runs_ok --label "[3/3] $com_label" --quiet
            set rc3 $status
            set -l com_why "$__ai_last_failure"
            test $rc3 -ne 0; and set com_note "failed: "(test -n "$com_why"; and echo $com_why; or echo "see the error above")
        else
            set com_note "skipped: no verdicts to build them from"
            set rc3 1
        end
    end
    set -l t_com (date +%s)

    # Deliver, after every stage: all the files of the run together, each path whole so it
    # can be used as it is. Without files: print the combined review + verification.
    if test -n "$review_out"
        _ai_ui_heading Saved
        _ai_ui_kv review $review_out
        if test $runs -gt 1
            set -l base (string replace -r '\.[^.]+$' '' -- $review_out)
            set -l ext (path extension -- $review_out)
            set -l kept (path filter -f -- $base.run(seq $runs)$ext)
            _ai_ui_kv runs $kept[1] "$runs_ok/$runs answered"
            for f in $kept[2..]
                _ai_ui_kv "" $f
            end
            _ai_runs_failed_lines $rev_failed
        end
        if test -s "$ver_target"
            _ai_ui_kv verify $verify_out (_ai_verdict_counts $ver_target)
            if set -q __ai_verify_run_files[1]
                _ai_ui_kv "verify runs" $__ai_verify_run_files[1] (_ai_verify_runs_note $vruns $__ai_verify_run_files)
                for f in $__ai_verify_run_files[2..]
                    _ai_ui_kv "" $f
                end
            end
            _ai_runs_failed_lines $ver_failed
        else
            # An empty file next to the review would read as a result — remove it
            rm -f "$ver_target"
            set_color yellow
            if test -n "$ver_why"
                _ai_ui_kv verify "failed: $ver_why"
            else
                _ai_ui_kv verify "no output ($verify_out not written)"
            end
            set_color normal
            _ai_runs_failed_lines $ver_failed
        end
        set -q _flag_comments; and test $rc3 -eq 0; and _ai_review_comments_saved $review_out $ver_target
        if test -n "$com_note"
            set_color yellow
            _ai_ui_kv comments $com_note
            set_color normal
        end
        set -l times "review "(math $t_rev - $t0)"s, verify "(math $t_ver - $t_rev)"s"
        set -q _flag_comments; and set times "$times, comments "(math $t_com - $t_ver)"s"
        _ai_ui_kv time (_ai_ui_duration (math $t_com - $t0)) "($times)"
    else
        cat $find_src
        echo ""
        set_color --bold; echo "## Verification"; set_color normal
        cat $ver_target
    end

    test $find_is_temp -eq 1; and rm -f $find_src
    test $ver_is_temp -eq 1; and rm -f $ver_target
    test $rc1 -eq 0; and test $rc2 -eq 0; and test $rc3 -eq 0
end
