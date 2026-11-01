function _ai_review_runs_plan --description "Runs and their mode for a review: prints runs<TAB>mode<TAB>why; refuses what cannot combine" --argument-names provider model runs_flag parallel no_parallel brief no_verify
    # Flag presence comes as 1 or empty. Several runs exist to be joined and judged by
    # verify, so they turn verify on — and refuse --brief / --no-verify.
    if test -n "$parallel"; and test -n "$no_parallel"
        echo "Error: --parallel and --no-parallel together" >&2
        return 1
    end
    set -l r (_ai_review_runs_count $provider "$model" "$runs_flag"); or return 1
    set r (string split \t -- $r)
    if test $r[1] -gt 1
        set -l why
        test -n "$brief"; and set why "several runs make a full review, not --brief"
        test -n "$no_verify"; and set why "several runs are joined for verify — drop --no-verify"
        if test -n "$why"
            echo "Error: $why (runs: $r[1] from $r[2])" >&2
            return 1
        end
    end
    set -l pflag
    test -n "$parallel"; and set pflag on
    test -n "$no_parallel"; and set pflag off
    set -l m (_ai_review_parallel_mode $provider "$model" "$pflag"); or return 1
    set m (string split \t -- $m)
    printf '%s\t%s\t%s\n' $r[1] $m[1] "runs from $r[2], $m[1]: $m[2]"
end
