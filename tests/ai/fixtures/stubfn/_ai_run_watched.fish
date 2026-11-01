function _ai_run_watched --description "Test stub: no model; run 1 of N answers a second late, so parallel runs end out of order"
    argparse 'label=' 'output=' 'dest=' -- $argv; or return 1
    cat >/dev/null
    string match -q -- '* run 1/*' $_flag_label; and sleep 1
    printf 'answer\n' >$_flag_output
    echo "  $_flag_label done" >&2
end
