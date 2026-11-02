function _ai_review_runs --description "Run the review N times (parallel or sequential) and join the runs into one review; how many answered goes to \$__ai_review_runs_ok, why the others failed to \$__ai_runs_failed"
    # Usage: _ai_review_runs --runs N --mode parallel|sequential --prompt-file F --output OUT
    #          --label L [--dest NAME] -- <_ai_run args>
    # The count is a global, not stdout: called as (_ai_review_runs …), fish would send the
    # stage lines on stderr past the caller's redirect (2>file, | tee) straight to the terminal.
    # One run of an agentic review is a sample: on the same 7 commits three runs found
    # three disjoint sets. N runs join under "## Run K/N" into OUT — the verify pass then
    # judges them all at once, and the comments stage merges what several runs reported.
    # Each run is kept as <base>.runK.<ext> with its own footer. A failed run does not
    # sink the rest: the join takes the runs that answered, and fails only if none did.
    # Each failed run's reason ("run K/N: why") goes to __ai_runs_failed for the caller's
    # final summary — the run's own lines have scrolled away by then.
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

    set -g __ai_runs_failed
    set -l t0 (date +%s)
    # The stage heading: the label up to " - provider…"; each run is one line under it
    set -l title (string replace -r ' - .*' '' -- $_flag_label)
    if test "$_flag_mode" = parallel
        _ai_ui_heading $title "$n runs in parallel (Ctrl-C stops them)" >&2
        set -l setfp "set -g fish_function_path "(string escape -- $fish_function_path | string join ' ')
        set -l logs
        set -l pids
        for k in (seq $n)
            set -l log (mktemp)
            set -a logs $log
            set -l cmd "$setfp; _ai_run_watched --label "(string escape -- "$_flag_label run $k/$n")" --row "(string escape -- "run $k/$n")" --output "(string escape -- $files[$k])" --dest "(string escape -- $files[$k])" -- "(string escape -- $run_args | string join ' ')
            fish --no-config -c $cmd <$_flag_prompt_file 2>$log &
            set -a pids $last_pid
        end
        # Each run's own done / FAILED line as soon as that run ends (the runs have no tty,
        # so no progress noise of their own); on a terminal, one live line for the stage
        # until the last one ends. fish drops a finished job from `jobs -p`.
        set -l tty 0
        isatty stderr; and set tty 1
        set -l left (seq $n)
        while set -q left[1]
            set -l running (jobs -p 2>/dev/null)
            for k in $left
                contains -- $pids[$k] $running; and continue
                test $tty -eq 1; and printf '\r\033[K' >&2
                cat $logs[$k] >&2
                # A failed run leaves an empty file (the join below skips it)
                if not test -s $files[$k]
                    set -l why (_ai_failure_reason <$logs[$k])
                    test -n "$why"; or set why "no answer"
                    set -a __ai_runs_failed "run $k/$n: $why"
                end
                rm -f $logs[$k]
                set -e left[(contains -i -- $k $left)]
            end
            set -q left[1]; or break
            test $tty -eq 1; and printf '\r\033[K  %d/%d done, %ds' \
                (math $n - (count $left)) $n (math (date +%s) - $t0) >&2
            sleep 1
        end
        wait
    else
        _ai_ui_heading $title "$n runs one after another (Ctrl-C stops them)" >&2
        for k in (seq $n)
            _ai_run_watched --label "$_flag_label run $k/$n" --row "run $k/$n" --output $files[$k] --dest $files[$k] -- $run_args <$_flag_prompt_file
            if not test -s $files[$k]
                set -l why "$__ai_last_failure"
                test -n "$why"; or set why "no answer"
                set -a __ai_runs_failed "run $k/$n: $why"
            end
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
    printf '  %d/%d answered, %ds\n' $ok $n (math (date +%s) - $t0) >&2
    set -g __ai_review_runs_ok $ok
    test $ok -gt 0
end
