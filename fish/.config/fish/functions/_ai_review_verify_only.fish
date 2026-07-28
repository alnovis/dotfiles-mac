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
    #   --agentic            accepted for interface symmetry (claude reads the repo by
    #                        default; local agentic runners are roadmap)
    #   --lang L, --dry-run
    argparse 'h/help' 'verify-only=' 'provider=' 'model=' 'lang=' 'o/output=' \
             'verify-provider=' 'verify-model=' 'verify-output=' 'file=' 'agentic' 'dry-run' -- $argv; or return 1

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

    set_color cyan
    echo "Verify-only: $review_file"
    set_color normal
    echo "Verify provider: $vprovider"
    test -n "$vmodel"; and echo "Verify model: $vmodel"
    if test "$vprovider" = ollama; and not set -q _flag_file
        set_color yellow
        echo "Note: no code embedded — a local verifier reasons from the findings text alone."
        echo "  Pass --file DIFF for grounding (or use --provider claude, which reads the repo itself)."
        set_color normal
    end
    echo "Output: $verify_out"
    echo "---"

    set -l vargs --provider $vprovider --workdir $workdir --findings-file $review_file --lang $lang_full
    test -n "$vmodel"; and set -a vargs --model $vmodel
    set -q _flag_agentic; and set -a vargs --agentic
    if set -q _flag_file; and test -f "$_flag_file"
        set -a vargs --code-file (realpath $_flag_file)
    end

    if set -q _flag_dry_run
        set -a vargs --dry-run
        _ai_review_verify $vargs
        return 0
    end

    set -l ver_label "Verify - $vprovider"
    test -n "$vmodel"; and set ver_label "$ver_label - $vmodel"
    _ai_stage_plan "$ver_label"
    _ai_review_verify $vargs --output $verify_out --label "$ver_label" --dest $verify_out
    set -l rc $status

    if test -s "$verify_out"
        set_color green
        echo "Verify saved to: $verify_out"
        set_color normal
    else
        set_color red
        echo "Verify produced no output — $verify_out is empty." >&2
        set_color normal
        return 1
    end
    return $rc
end
