function _ai_run_watched --description "Test stub: no model; run 1 of N answers 3 s late, so parallel runs end out of order"
    argparse 'label=' 'output=' 'dest=' -- $argv; or return 1
    cat >/dev/null
    # Late by more than one poll of _ai_review_runs (1 s): a 1 s delay let both runs end
    # between two polls on a busy machine, and the lines came out in run order
    string match -q -- '* run 1/*' $_flag_label; and sleep 3
    printf 'answer\n' >$_flag_output
    echo "  $_flag_label done" >&2
end
