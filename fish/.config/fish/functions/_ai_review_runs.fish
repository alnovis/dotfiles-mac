function _ai_review_runs --description "Run the review N times (parallel or sequential) and join the runs into one review; prints how many succeeded"
    # Usage: _ai_review_runs --runs N --mode parallel|sequential --prompt-file F --output OUT
    #          --label L [--dest NAME] -- <_ai_run args>
    # One run of an agentic review is a sample: on the same 7 commits three runs found
    # three disjoint sets. N runs join under "## Run K/N" into OUT — the verify pass then
    # judges them all at once, and the comments stage merges what several runs reported.
    # Each run is kept as <base>.runK.<ext> with its own footer. A failed run does not
    # sink the rest: the join takes the runs that answered, and fails only if none did.
    #
    # Parallel runs are separate fish processes: a backgrounded fish function runs in the
    # same process, one after another.
    argparse 'runs=' 'mode=' 'prompt-file=' 'output=' 'label=' 'dest=' -- $argv; or return 1
    set -l n $_flag_runs
    set -l out $_flag_output
    set -l run_args $argv
    set -l dest $_flag_dest
    test -n "$dest"; or set dest $out

    # Run files next to the report (or temps when the review goes to the terminal)
    set -l files
    for k in (seq $n)
        if test "$dest" = "(terminal)"
            set -a files (mktemp)
        else
            set -l dir (path dirname -- $dest)
            set -l base (path basename -- $dest | string replace -r '\.[^.]+$' '')
            set -l ext (path extension -- $dest)
            set -a files $dir/$base.run$k$ext
        end
    end

    set -l t0 (date +%s)
    if test "$_flag_mode" = parallel
        printf '  %s | %d runs in parallel… (Ctrl-C stops them)\n' $_flag_label $n >&2
        set -l setfp "set -g fish_function_path "(string escape -- $fish_function_path | string join ' ')
        set -l logs
        for k in (seq $n)
            set -l log (mktemp)
            set -a logs $log
            set -l cmd "$setfp; _ai_run_watched --label "(string escape -- "$_flag_label run $k/$n")" --output "(string escape -- $files[$k])" --dest "(string escape -- $files[$k])" -- "(string escape -- $run_args | string join ' ')
            fish --no-config -c $cmd <$_flag_prompt_file 2>$log &
        end
        wait
        # Each run's own done / FAILED lines (non-tty, so no progress noise)
        for log in $logs
            cat $log >&2
            rm -f $log
        end
    else
        for k in (seq $n)
            _ai_run_watched --label "$_flag_label run $k/$n" --output $files[$k] --dest $files[$k] -- $run_args <$_flag_prompt_file
        end
    end

    set -l ok 0
    : >$out
    for k in (seq $n)
        # A failed run leaves an empty file that would read as a result
        if not test -s $files[$k]
            rm -f $files[$k]
            continue
        end
        set ok (math $ok + 1)
        printf '## Run %d/%d\n\n' $k $n >>$out
        cat $files[$k] >>$out
        printf '\n\n' >>$out
    end
    test "$dest" = "(terminal)"; and rm -f $files
    printf '  %s | %d/%d runs answered | %ds -> %s\n' $_flag_label $ok $n (math (date +%s) - $t0) $dest >&2
    echo $ok
    test $ok -gt 0
end
