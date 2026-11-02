function _ai_verify_runs_count --description "How many verify runs for the verify PROVIDER/MODEL: --verify-runs FLAG > verify_runs (scoped) > 1; prints count<TAB>origin" --argument-names provider model flag
    # More than one: the runs are joined by majority vote per finding (_ai_verify_vote).
    # One verify run is a sample: on the same review its verdict on a finding flipped
    # between runs, while the majority of three was right every time.
    set -l n
    set -l origin
    if test -n "$flag"
        set n $flag
        set origin "--verify-runs"
    else
        set -l s (_ai_review_setting verify_runs $provider $model | string split \t)
        if test -n "$s[1]"
            set n $s[1]
            set origin "config $s[2]"
        else
            set n 1
            set origin default
        end
    end
    if not string match -qr '^[1-9][0-9]*$' -- $n
        echo "Error: verify runs must be a positive integer (got '$n' from $origin)" >&2
        return 1
    end
    printf '%s\t%s\n' $n $origin
end
