function _ai_review_runs_count --description "How many review runs for PROVIDER/MODEL: --runs FLAG > review_runs (scoped) > 1; prints count<TAB>origin" --argument-names provider model flag
    set -l n
    set -l origin
    if test -n "$flag"
        set n $flag
        set origin "--runs"
    else
        set -l s (_ai_review_setting review_runs $provider $model | string split \t)
        if test -n "$s[1]"
            set n $s[1]
            set origin "config $s[2]"
        else
            set n 1
            set origin default
        end
    end
    if not string match -qr '^[1-9][0-9]*$' -- $n
        echo "Error: review runs must be a positive integer (got '$n' from $origin)" >&2
        return 1
    end
    printf '%s\t%s\n' $n $origin
end
