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
    #   --range BASE..HEAD       the reviewed range, for anchoring those comments
    argparse 'prompt-file=' 'provider=' 'model=' 'workdir=' 'output=' 'verify-output=' 'lang=' 'dry-run' 'agentic' 'no-think' \
             'verify-provider=' 'verify-model=' 'code-file=' 'comments' 'range=' -- $argv; or return 1

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
        printf '%s' "$pass1_prompt" | _ai_run $run_args --dry-run
        set_color cyan >&2; echo "--- dry-run: pass 2 (verify) ---" >&2; set_color normal >&2
        set -l code_note "no code"
        if test -n "$_flag_code_file"; and test -f "$_flag_code_file"
            set code_note "code: "(count (cat $_flag_code_file))" lines"
        end
        echo "verify provider=$vprovider model=$vmodel (prompt: meta-verify.md + first-pass findings + $code_note)" >&2
        test -n "$review_out"; and echo "would write: review -> $review_out ; verify -> $verify_out" >&2
        if set -q _flag_comments
            set_color cyan >&2; echo "--- dry-run: pass 3 (comments) ---" >&2; set_color normal >&2
            _ai_review_comments --dry-run --output $review_out --provider $vprovider --model "$vmodel" --range "$_flag_range"
        end
        return 0
    end

    # Comments are a third stage: the same verify model turns the verdicts into MR comments
    set -l n_stages 2
    set -q _flag_comments; and set n_stages 3
    set -l rev_label "Review - $provider"
    test -n "$model"; and set rev_label "$rev_label - $model"
    set -l ver_label "Verify - $vprovider"
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

    printf '%s' "$pass1_prompt" | _ai_run_watched --label "[1/$n_stages] $rev_label" --output $find_src --dest $rev_dest -- $run_args
    set -l rc1 $status

    if test $rc1 -ne 0; or not test -s $find_src
        echo "  Review pass produced no output (provider=$provider). Aborting before verify." >&2
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

    # Pass 2 — verify.
    set -l vargs --provider $vprovider --workdir $workdir --findings-file $find_src
    test -n "$vmodel"; and set -a vargs --model $vmodel
    test -n "$lang"; and set -a vargs --lang $lang
    test -n "$_flag_code_file"; and set -a vargs --code-file $_flag_code_file
    set -q _flag_agentic; and set -a vargs --agentic
    set -q _flag_no_think; and set -a vargs --no-think

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

    _ai_review_verify $vargs --output $ver_target --label "[2/$n_stages] $ver_label" --dest $ver_dest
    set -l rc2 $status

    # Stage 3 — comments, only over a verify pass that produced verdicts
    set -l rc3 0
    set -l com_note
    if set -q _flag_comments; and test -n "$review_out"
        if test -s "$ver_target"
            _ai_review_comments --findings $find_src --verdicts $ver_target --output $review_out \
                --provider $vprovider --model "$vmodel" --lang "$lang" --range "$_flag_range" --root $workdir \
                --label "[3/3] $com_label" --quiet
            set rc3 $status
        else
            set com_note "Comments skipped: no verdicts to build them from."
            set rc3 1
        end
    end

    # Deliver, after every stage: all the files of the run together. Without files: print
    # the combined review + verification to the terminal.
    if test -n "$review_out"
        set_color green
        echo "Review saved to:   $review_out"
        if test -s "$ver_target"
            echo "Verify saved to:   $verify_out"
        else
            # An empty file next to the review would read as a result — remove it
            rm -f "$ver_target"
            set_color yellow
            echo "Verify produced no output ($verify_out not written)."
        end
        set_color green
        set -q _flag_comments; and test $rc3 -eq 0; and _ai_review_comments_saved $review_out $ver_target
        set_color yellow
        test -n "$com_note"; and echo $com_note
        set -q _flag_comments; and test -z "$com_note"; and test $rc3 -ne 0
        and echo "Comments not written (see the error above)."
        set_color normal
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
