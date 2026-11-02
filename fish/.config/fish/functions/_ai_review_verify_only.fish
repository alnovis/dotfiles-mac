function _ai_review_verify_only --description "Run ONLY the verify pass over an already-saved review file"
    # `ai review --verify-only FILE` — re-verify an existing review without re-running
    # the (possibly expensive) review pass. The point: a costly claude review can be
    # verified, or re-verified with a different model, for free.
    #   --verify-only FILE   the saved review to verify (required)
    #   --provider/--model   default verifier (if no --verify-* given)
    #   --verify-provider/--verify-model   the verifier (win over --provider/--model)
    #   --verify-output FILE explicit output (default: <review>.verify.<ext>)
    #   -o/--output FILE     alias for --verify-output here (there is no review to write)
    #   --file FILE          optional code/diff file to embed for the verifier
    #   --agentic            passed to the verifier: it reads the repo read-only (claude via
    #                        its CLI, any other provider via the runner, see _ai_default_agent)
    #   --no-think           passed to the verifier (fast pass, think:false)
    #   --lens A,B           the review's lenses, as knowledge to judge the findings by
    #   --lang L, --dry-run
    #   --comments           then MR line comments from the verdicts (<review>.comments.md/.json)
    #   --range BASE..HEAD   the reviewed range, to anchor the comments and check the diff
    #   --verdicts FILE      an existing verify file: skip the verify pass, build comments only
    argparse 'h/help' 'verify-only=' 'provider=' 'model=' 'lang=' 'o/output=' \
             'verify-provider=' 'verify-model=' 'verify-output=' 'file=' 'agentic' 'no-think' 'dry-run' \
             'comments' 'range=' 'verdicts=' 'lens=' 'no-lens' 'verify-runs=' -- $argv; or return 1
    # Lenses: --lens, else review_lens from the project's (or the global) config; --no-lens: none
    if set -q _flag_lens; and set -q _flag_no_lens
        echo "Error: --lens and --no-lens exclude each other" >&2
        return 1
    end
    set -l lc (_ai_review_lens_choice "$_flag_lens" "$(set -q _flag_no_lens; and echo 1)" | string split \t)
    test -n "$lc[1]"; and set _flag_lens $lc[1]

    set -l review_file $_flag_verify_only
    if test -z "$review_file"; or not test -f "$review_file"
        set_color red
        echo "Error: --verify-only needs an existing review file (got: '$review_file')" >&2
        set_color normal
        return 1
    end
    set review_file (realpath $review_file)

    # Verifier provider/model: --verify-* > --provider/--model > config/default.
    set -l vprovider $_flag_verify_provider
    test -z "$vprovider"; and set vprovider $_flag_provider
    if test -z "$vprovider"
        set vprovider (_ai_config_read verify_provider); test $status -ne 0; and set vprovider ""
    end
    test -z "$vprovider"; and set vprovider (_ai_default_provider review)

    set -l vmodel $_flag_verify_model
    test -z "$vmodel"; and set vmodel $_flag_model
    test -z "$vmodel"; and set vmodel (_ai_default_model verify $vprovider)

    set -l lang en
    test -n "$_flag_lang"; and set lang $_flag_lang
    set -l lang_full (_ai_lang_name $lang)

    # Output: --verify-output > -o > derived from the review file.
    set -l verify_out $_flag_verify_output
    test -z "$verify_out"; and set verify_out $_flag_output
    test -z "$verify_out"; and set verify_out (_ai_verify_output_path $review_file)

    set -l workdir (pwd)

    # --range also gives the verifier the diff, so it works without --comments
    if set -q _flag_verdicts; and not set -q _flag_comments
        set_color red
        echo "Error: --verdicts is for --comments" >&2
        set_color normal
        return 1
    end
    # An existing verify file: no verify pass, straight to the comments
    if set -q _flag_verdicts
        if not test -s "$_flag_verdicts"
            set_color red
            echo "Error: --verdicts needs an existing verify file (got: '$_flag_verdicts')" >&2
            set_color normal
            return 1
        end
        set -l verdicts (realpath $_flag_verdicts)
        set -l cargs --findings $review_file --verdicts $verdicts --output $review_file \
            --provider $vprovider --model "$vmodel" --lang $lang_full --range "$_flag_range" --root $workdir
        set -q _flag_dry_run; and set -a cargs --dry-run
        echo "Comments from: $review_file + $verdicts"
        echo "---"
        _ai_review_comments $cargs --label "Comments - $vprovider"(test -n "$vmodel"; and echo " - $vmodel")
        return
    end

    set_color cyan
    echo "Verify-only: $review_file"
    set_color normal
    echo "Verify provider: $vprovider"
    test -n "$vmodel"; and echo "Verify model: $vmodel"
    # The diff of --range, when no --file: without the removed lines the verifier cannot
    # tell a regression from a pre-existing problem, and guesses "pre-existing"
    set -l diff_tmp
    if not set -q _flag_file; and set -q _flag_range
        set diff_tmp (mktemp)
        if not git diff $_flag_range >$diff_tmp 2>/dev/null; or not test -s $diff_tmp
            rm -f $diff_tmp
            set_color red
            echo "Error: --range $_flag_range gives no diff here (run it from the repo, check the range)" >&2
            set_color normal
            return 1
        end
        echo "Code: the diff of $_flag_range ("(count (cat $diff_tmp))" lines)"
    end
    if not set -q _flag_file; and test -z "$diff_tmp"
        set_color yellow
        if set -q _flag_agentic
            echo "Note: no diff — the verifier reads the repo but cannot see the old code, so it cannot"
            echo "  tell a regression from a pre-existing problem. Pass --range BASE..HEAD (or --file DIFF)."
        else
            echo "Note: no code embedded — the verifier reasons from the findings text alone."
            echo "  Pass --range BASE..HEAD (or --file DIFF) for grounding, or --agentic to let it read the repo."
        end
        set_color normal
    end
    echo "Output: $verify_out"
    echo "---"

    # Verify runs: --verify-runs > verify_runs (scoped) > 1, joined by majority per finding
    # Checked outside (…) first: stderr inside it skips the caller's redirect
    _ai_verify_runs_count $vprovider "$vmodel" "$_flag_verify_runs" >/dev/null; or return 1
    set -l vr (_ai_verify_runs_count $vprovider "$vmodel" "$_flag_verify_runs" | string split \t)
    set -l vruns $vr[1]
    set -l vmode sequential
    if test $vruns -gt 1
        set -l vm (_ai_review_parallel_mode $vprovider "$vmodel" "" | string split \t)
        test -n "$vm[1]"; and set vmode $vm[1]
        echo "Verify runs: $vruns ($vmode), joined by majority per finding (origin: $vr[2])"
    end

    set -l vargs --provider $vprovider --workdir $workdir --findings-file $review_file --lang $lang_full
    test -n "$vmodel"; and set -a vargs --model $vmodel
    set -q _flag_lens; and set -a vargs --lens $_flag_lens
    set -q _flag_agentic; and set -a vargs --agentic
    set -q _flag_no_think; and set -a vargs --no-think
    if set -q _flag_file; and test -f "$_flag_file"
        set -a vargs --code-file (realpath $_flag_file)
    else if test -n "$diff_tmp"
        set -a vargs --code-file $diff_tmp
    end

    set -l com_args --findings $review_file --verdicts $verify_out --output $review_file \
        --provider $vprovider --model "$vmodel" --lang $lang_full --range "$_flag_range" --root $workdir

    if set -q _flag_dry_run
        set -a vargs --dry-run
        _ai_review_verify $vargs
        set -q _flag_comments; and _ai_review_comments $com_args --dry-run
        test -n "$diff_tmp"; and rm -f $diff_tmp
        return 0
    end

    set -l ver_label "Verify - $vprovider"
    test -n "$vmodel"; and set ver_label "$ver_label - $vmodel"
    set -l com_label (string replace Verify Comments -- $ver_label)
    test $vruns -gt 1; and set ver_label (string replace Verify "Verify ×$vruns" -- $ver_label)
    if set -q _flag_comments
        _ai_stage_plan "$ver_label" "$com_label"
        set ver_label "[1/2] $ver_label"
        set com_label "[2/2] $com_label"
    else
        _ai_stage_plan "$ver_label"
    end
    set -e __ai_verify_run_files
    _ai_review_verify $vargs --runs $vruns --mode $vmode --output $verify_out --label "$ver_label" --dest $verify_out
    set -l rc $status
    test -n "$diff_tmp"; and rm -f $diff_tmp

    if not test -s "$verify_out"
        rm -f "$verify_out"
        set_color red
        if test -n "$__ai_last_failure"
            echo "Verify failed:     $__ai_last_failure" >&2
        else
            echo "Verify produced no output ($verify_out not written)." >&2
        end
        set_color normal
        return 1
    end
    set -l rc3 0
    set -l com_why
    if set -q _flag_comments
        _ai_review_comments $com_args --label $com_label --quiet
        set rc3 $status
        set com_why "$__ai_last_failure"
    end

    # Every file of the run together, after the last stage
    set_color green
    echo "Verify saved to:   $verify_out ("(_ai_verdict_counts $verify_out)")"
    if set -q __ai_verify_run_files[1]
        echo "Verify runs:       $__ai_verify_run_files[1] ("(count $__ai_verify_run_files)"/$vruns answered, majority above)"
        for f in $__ai_verify_run_files[2..]
            echo "                   $f"
        end
    end
    set -q _flag_comments; and test $rc3 -eq 0; and _ai_review_comments_saved $review_file $verify_out
    set_color yellow
    test $rc3 -ne 0; and echo "Comments failed:   "(test -n "$com_why"; and echo $com_why; or echo "see the error above")
    set_color normal
    test $rc3 -eq 0; or set rc 1
    return $rc
end
