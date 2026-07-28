function _ai_run_watched --description "Run a provider (via _ai_run) into a file with a progress readout, Ctrl-C safe"
    # Usage: printf PROMPT | _ai_run_watched --label L --output FILE [--dest NAME] -- <_ai_run args>
    #
    # ONE foreground pipeline — _ai_run | tee FILE | (count lines). The model runs in
    # the FOREGROUND on purpose: Ctrl-C then reaches curl, curl disconnects, and
    # ollama aborts generation — so an interrupt actually STOPS the model instead of
    # leaving it burning compute. (Backgrounding the model to get a prefill ticker was
    # tried and rejected: it puts the model in its own process group where Ctrl-C
    # can't reach it — verified to orphan curl on interrupt. A reliable stop beats a
    # nicer spinner.) The cost: fish `read` has no timeout, so this can only update as
    # lines arrive — during generation, NOT during the model's silent prefill. So we
    # print an honest up-front prefill-time ESTIMATE, then a live line count once
    # output flows, then the final line.
    argparse 'label=' 'output=' 'dest=' -- $argv; or return 1
    set -l label $_flag_label
    set -l outfile $_flag_output
    set -l dest $_flag_dest
    test -z "$dest"; and set dest $outfile
    set -l run_args $argv

    set -l t0 (date +%s)
    : >$outfile
    set -l errlog (mktemp)
    set -l pfile (mktemp)
    cat >$pfile

    set -l tty 0
    isatty stderr; and set tty 1

    set -l rc
    if contains -- --agentic $run_args
        # Agentic: the agent-runner streams its OWN live turn/tool/ctx progress to
        # stderr — show it (do NOT redirect the runner's stderr) and don't draw a
        # second line here. Its final answer (stdout) is redirected to the file.
        test $tty -eq 1; and printf '  %s | agentic — exploring the repo with tools (dynamic context; Ctrl-C stops it)\n' $label >&2
        _ai_run $run_args <$pfile >$outfile
        set rc $status
    else
        # Non-agentic single call: `read` has no timeout, so update only as lines
        # arrive; print an honest prefill estimate, then a live line count.
        set -l chars (wc -c <$pfile | string trim)
        set -l tokens (math "round($chars / 3.5)")
        set -l esec (math "round($tokens / 120)")
        set -l etime "~"$esec"s"
        test $esec -ge 90; and set etime "~"(math "round($esec / 60)")"m"
        test $tty -eq 1; and printf '  %s | working… (~%dk-token context, est %s prefill — local models are slow on big context, output appears at the end; Ctrl-C stops the model)' \
            $label (math "round($tokens / 1000)") $etime >&2

        set -l n 0
        _ai_run $run_args <$pfile 2>$errlog | tee $outfile | while read -l line
            set n (math $n + 1)
            if test $tty -eq 1; and test (math $n % 3) -eq 0
                printf '\r\033[K  %s | %ds | %d lines -> %s' \
                    $label (math (date +%s) - $t0) $n $dest >&2
            end
        end
        set rc $pipestatus[1]
    end

    set -l total (math (date +%s) - $t0)
    set -l lines (wc -l <$outfile 2>/dev/null | string trim)
    test $tty -eq 1; and printf '\r\033[K' >&2
    if test "$rc" -eq 0
        printf '  %s done | %ds | %s lines -> %s\n' $label $total "$lines" $dest >&2
    else
        printf '  %s FAILED (rc %s) | %ds -> %s\n' $label "$rc" $total $dest >&2
        test -s $errlog; and cat $errlog >&2
    end
    rm -f $errlog $pfile
    return $rc
end
