function _ai_run_watched --description "Test stub: no model; run 1 of N answers 3 s late, so parallel runs end out of order; run \$AI_STUB_FAIL fails"
    argparse 'label=' 'output=' 'dest=' -- $argv; or return 1
    cat >/dev/null
    # Late by more than one poll of _ai_review_runs (1 s): a 1 s delay let both runs end
    # between two polls on a busy machine, and the lines came out in run order
    string match -q -- '* run 1/*' $_flag_label; and sleep 3
    # A failed run as the real one leaves it: the runner's reason, then our FAILED line,
    # an empty output file, the reason in __ai_last_failure
    if set -q AI_STUB_FAIL; and string match -q -- "* run $AI_STUB_FAIL/*" $_flag_label
        : >$_flag_output
        echo "Response was truncated: the model reached its output token limit." >&2
        echo "  $_flag_label FAILED (rc 1)" >&2
        set -g __ai_last_failure "Response was truncated: the model reached its output token limit."
        return 1
    end
    printf 'answer\n' >$_flag_output
    echo "  $_flag_label done" >&2
end
