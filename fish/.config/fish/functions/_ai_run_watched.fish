function _ai_run_watched --description "Run a provider (via _ai_run) into a file with a progress readout, Ctrl-C safe"
    # Usage: printf PROMPT | _ai_run_watched --label L --output FILE [--dest NAME]
    #          [--heading | --row NAME] -- <_ai_run args>
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
    #
    # On the screen a run is ONE line under its stage heading: "  [NAME  ]done  448s  <stats>
    # <file>" (or FAILED and why), the progress drawn in its place until then. --heading
    # prints the stage heading first — the label up to " - provider…", a single run's stage;
    # --row NAME ("run 2/3") names the run in a stage of several (_ai_review_runs prints
    # that heading). The label in full (provider, model) goes into the report's "Run:" line.
    argparse 'label=' 'output=' 'dest=' 'heading' 'row=' -- $argv; or return 1
    set -l label $_flag_label
    set -l outfile $_flag_output
    set -l dest $_flag_dest
    test -z "$dest"; and set dest $outfile
    set -l run_args $argv
    set -l name ""
    test -n "$_flag_row"; and set name (string pad -r -w 9 -- $_flag_row)
    set -l agentic 0
    contains -- --agentic $run_args; and set agentic 1

    # Reasoning sidecar: when the report has a real destination (not a temp streamed to
    # the terminal), the model's thinking goes next to it as <base>.thinking.<ext>. Made
    # absolute up front because _ai_run cd's into --workdir before the provider writes it
    # — a relative path would otherwise land in the repo, not beside the report. Only the
    # non-agentic ollama path supports it (agent runners have no such channel yet).
    set -l sidecar ""
    if test -n "$dest"; and test "$dest" != "(terminal)"; and test $agentic -eq 0
        set sidecar (_ai_thinking_output_path $dest)
        string match -q '/*' -- $sidecar; or set sidecar $PWD/$sidecar
    end

    # The agentic runner may print on stderr, so no progress line to clear there: the
    # note goes on the heading instead
    if set -q _flag_heading
        set -l note
        test $agentic -eq 1; and set note "exploring the repo with tools (Ctrl-C stops it)"
        _ai_ui_heading (string replace -r ' - .*' '' -- $label) "$note" >&2
    end

    set -l t0 (date +%s)
    : >$outfile
    set -l errlog (mktemp)
    set -l pfile (mktemp)
    cat >$pfile

    set -l tty 0
    isatty stderr; and set tty 1

    set -l chars (wc -c <$pfile | string trim)
    set -l tokens (math "round($chars / 3.5)")
    # Exact token counts from the native drivers and the pi runner, for the stats
    set -l ufile (mktemp)

    set -l rc
    if test $agentic -eq 1
        # Agentic: the runner (pi / opencode / claude) may print its own progress on
        # stderr — leave it visible (do NOT redirect it). Its final answer (stdout) is
        # redirected to the file.
        _ai_run $run_args --usage-output $ufile <$pfile >$outfile
        set rc $status
    else
        # Non-agentic single call: `read` has no timeout, so update only as lines
        # arrive; print an honest prefill estimate, then a live line count.
        # The prefill estimate is about a local model; a cloud one starts in seconds. Kept to
        # one line: a wrapped line can't be cleared with \r, and the result would stick to it.
        set -l provider
        set -l pi (contains -i -- --provider $run_args)
        test -n "$pi"; and set provider $run_args[(math $pi + 1)]
        if test $tty -eq 1
            if test "$provider" = ollama
                set -l esec (math "round($tokens / 120)")
                set -l etime "~"$esec"s"
                test $esec -ge 90; and set etime "~"(math "round($esec / 60)")"m"
                printf '  %sworking… ~%dk tokens, est %s prefill (Ctrl-C stops it)' \
                    $name (math "round($tokens / 1000)") $etime >&2
            else
                printf '  %sworking… ~%dk tokens (Ctrl-C stops it)' $name (math "round($tokens / 1000)") >&2
            end
        end

        set -l n 0
        set -l na_args $run_args --usage-output $ufile
        test -n "$sidecar"; and set -a na_args --thinking-output $sidecar
        _ai_run $na_args <$pfile 2>$errlog | tee $outfile | while read -l line
            set n (math $n + 1)
            if test $tty -eq 1; and test (math $n % 3) -eq 0
                printf '\r\033[K  %sworking… %ds, %d lines' $name (math (date +%s) - $t0) $n >&2
            end
        end
        set rc $pipestatus[1]
        test $tty -eq 1; and printf '\r\033[K' >&2
    end

    set -l total (math (date +%s) - $t0)
    # A non-empty sidecar means the model reasoned; an empty one means it didn't (or
    # wasn't a thinking model) — drop it so no stray files accumulate.
    set -l thinking_bytes 0
    if test -n "$sidecar"
        if test -s "$sidecar"
            set thinking_bytes (wc -c <$sidecar | string trim)
        else
            rm -f "$sidecar"
        end
    end

    # Success with nothing written is a failure: a reasoning model can spend the whole
    # max_tokens thinking and end without an answer, and the runner still exits 0.
    # The reason of a failure, one line, for the caller's final summary — it scrolls away
    # above otherwise: the last error-looking line of the log, else its last line
    set -g __ai_last_failure ""
    if test "$rc" -eq 0; and not test -s $outfile
        set rc 1
        set -g __ai_last_failure "the model returned no answer (max_tokens spent thinking?)"
        _ai_run_watched_row "$name" FAILED $total $__ai_last_failure >&2
        printf '    A reasoning model may have used up max_tokens thinking: raise maxTokens for the model in the runner config, rerun, or pick another model.\n' >&2
        test -s $errlog; and string replace -r '^' '    ' <$errlog >&2
    else if test "$rc" -ne 0
        set -l why (_ai_failure_reason <$errlog)
        test -n "$why"; or set why "exit $rc"
        set -g __ai_last_failure $why
        _ai_run_watched_row "$name" FAILED $total $why >&2
        test -s $errlog; and string replace -r '^' '    ' <$errlog >&2
    else
        set -l file $dest
        test "$dest" = "(terminal)"; and set file ""
        _ai_run_watched_row "$name" done $total (_ai_run_stats --row $ufile $tokens $thinking_bytes) $file >&2
        test -n "$sidecar"; and test -s "$sidecar"; and printf '    reasoning  %s\n' $sidecar >&2
        # The report's last line, "Run: …": comparing toolkit versions or models later needs
        # nothing but the files (grep -h '^Run: '). Plain text: the reports are read in a
        # terminal far more often than rendered. Not into a temp printed to the terminal.
        if test -n "$file"
            set -l line "Run: $label | $total"s
            for p in (_ai_run_stats $ufile $tokens $thinking_bytes)
                set line "$line | "(string replace \t ' ' -- $p)
            end
            printf '\n---\n%s\n' $line >>$outfile
        end
    end
    rm -f $errlog $pfile $ufile
    return $rc
end

function _ai_run_watched_row --description "The run's line: [NAME] STATUS SECONDS TEXT [FILE], in fixed columns" --argument-names name state secs text file
    printf '  %s' $name
    if test $state = done
        set_color green
    else
        set_color red
    end
    printf '%-6s' $state
    set_color normal
    printf '  %5s  %s' $secs"s" $text
    test -n "$file"; and printf '  %s' $file
    echo
end
