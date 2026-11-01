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
    #   --lang L, --dry-run
    #   --comments           then MR line comments from the verdicts (<review>.comments.md/.json)
    #   --range BASE..HEAD   the reviewed range, to anchor the comments and check the diff
    #   --verdicts FILE      an existing verify file: skip the verify pass, build comments only
    argparse 'h/help' 'verify-only=' 'provider=' 'model=' 'lang=' 'o/output=' \
             'verify-provider=' 'verify-model=' 'verify-output=' 'file=' 'agentic' 'no-think' 'dry-run' \
             'comments' 'range=' 'verdicts=' -- $argv; or return 1

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

    if set -q _flag_verdicts; or set -q _flag_range
        if not set -q _flag_comments
            set_color red
            echo "Error: --verdicts and --range are for --comments" >&2
            set_color normal
            return 1
        end
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
    if not set -q _flag_file; and not set -q _flag_agentic
        set_color yellow
        echo "Note: no code embedded — the verifier reasons from the findings text alone."
        echo "  Pass --file DIFF for grounding, or --agentic to let it read the repo."
        set_color normal
    end
    echo "Output: $verify_out"
    echo "---"

    set -l vargs --provider $vprovider --workdir $workdir --findings-file $review_file --lang $lang_full
    test -n "$vmodel"; and set -a vargs --model $vmodel
    set -q _flag_agentic; and set -a vargs --agentic
    set -q _flag_no_think; and set -a vargs --no-think
    if set -q _flag_file; and test -f "$_flag_file"
        set -a vargs --code-file (realpath $_flag_file)
    end

    set -l com_args --findings $review_file --verdicts $verify_out --output $review_file \
        --provider $vprovider --model "$vmodel" --lang $lang_full --range "$_flag_range" --root $workdir

    if set -q _flag_dry_run
        set -a vargs --dry-run
        _ai_review_verify $vargs
        set -q _flag_comments; and _ai_review_comments $com_args --dry-run
        return 0
    end

    set -l ver_label "Verify - $vprovider"
    test -n "$vmodel"; and set ver_label "$ver_label - $vmodel"
    set -l com_label (string replace Verify Comments -- $ver_label)
    if set -q _flag_comments
        _ai_stage_plan "$ver_label" "$com_label"
        set ver_label "[1/2] $ver_label"
        set com_label "[2/2] $com_label"
    else
        _ai_stage_plan "$ver_label"
    end
    _ai_review_verify $vargs --output $verify_out --label "$ver_label" --dest $verify_out
    set -l rc $status

    if not test -s "$verify_out"
        rm -f "$verify_out"
        set_color red
        echo "Verify produced no output ($verify_out not written)." >&2
        set_color normal
        return 1
    end
    set -l rc3 0
    if set -q _flag_comments
        _ai_review_comments $com_args --label $com_label --quiet
        set rc3 $status
    end

    # Every file of the run together, after the last stage
    set_color green
    echo "Verify saved to:   $verify_out"
    set -q _flag_comments; and test $rc3 -eq 0; and _ai_review_comments_saved $review_file $verify_out
    set_color normal
    test $rc3 -eq 0; or set rc 1
    return $rc
end
