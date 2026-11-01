function _ai_review_parallel_mode --description "parallel or sequential for PROVIDER/MODEL: --parallel/--no-parallel > review_parallel (scoped: auto|on|off) > auto; prints mode<TAB>origin" --argument-names provider model flag
    # FLAG: on | off | empty. auto runs cloud providers in parallel and ollama one at a
    # time — several local runs at once would not fit in memory.
    set -l v $flag
    set -l origin
    if test -n "$v"
        set origin (test $v = on; and echo "--parallel"; or echo "--no-parallel")
    else
        set -l s (_ai_review_setting review_parallel $provider $model | string split \t)
        set v $s[1]
        set origin "config $s[2]"
        if test -z "$v"
            set v auto
            set origin default
        end
    end
    switch $v
        case on
            printf 'parallel\t%s\n' $origin
        case off
            printf 'sequential\t%s\n' $origin
        case auto
            if test "$provider" = ollama
                printf 'sequential\t%s\n' "auto: a local model"
            else
                printf 'parallel\t%s\n' "auto: a cloud provider"
            end
        case '*'
            echo "Error: review_parallel must be auto, on or off (got '$v' from $origin)" >&2
            return 1
    end
end
