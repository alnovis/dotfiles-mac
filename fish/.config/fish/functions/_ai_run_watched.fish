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

    # Reasoning sidecar: when the report has a real destination (not a temp streamed to
    # the terminal), the model's thinking goes next to it as <base>.thinking.<ext>. Made
    # absolute up front because _ai_run cd's into --workdir before the provider writes it
    # — a relative path would otherwise land in the repo, not beside the report. Only the
    # non-agentic ollama path supports it (agent runners have no such channel yet).
    set -l sidecar ""
    if test -n "$dest"; and test "$dest" != "(terminal)"; and not contains -- --agentic $run_args
        set sidecar (_ai_thinking_output_path $dest)
        string match -q '/*' -- $sidecar; or set sidecar $PWD/$sidecar
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
    # Exact token counts from the native drivers, for the report footer
    set -l ufile (mktemp)

    set -l rc
    if contains -- --agentic $run_args
        # Agentic: the runner (pi / opencode / claude) may print its own progress on
        # stderr — leave it visible (do NOT redirect it) and don't draw a second line
        # here. Its final answer (stdout) is redirected to the file.
        test $tty -eq 1; and printf '  %s | agentic — exploring the repo with tools (Ctrl-C stops it)\n' $label >&2
        _ai_run $run_args <$pfile >$outfile
        set rc $status
    else
        # Non-agentic single call: `read` has no timeout, so update only as lines
        # arrive; print an honest prefill estimate, then a live line count.
        # The prefill estimate is about a local model; a cloud one starts in seconds. Kept to
        # one line: a wrapped line can't be cleared with \r, and "done" would stick to it.
        set -l provider
        set -l pi (contains -i -- --provider $run_args)
        test -n "$pi"; and set provider $run_args[(math $pi + 1)]
        if test $tty -eq 1
            if test "$provider" = ollama
                set -l esec (math "round($tokens / 120)")
                set -l etime "~"$esec"s"
                test $esec -ge 90; and set etime "~"(math "round($esec / 60)")"m"
                printf '  %s | working… ~%dk tokens, est %s prefill (Ctrl-C stops it)' \
                    $label (math "round($tokens / 1000)") $etime >&2
            else
                printf '  %s | working… ~%dk tokens (Ctrl-C stops it)' $label (math "round($tokens / 1000)") >&2
            end
        end

        set -l n 0
        set -l na_args $run_args --usage-output $ufile
        test -n "$sidecar"; and set -a na_args --thinking-output $sidecar
        _ai_run $na_args <$pfile 2>$errlog | tee $outfile | while read -l line
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
    # Success with nothing written is a failure: a reasoning model can spend the whole
    # max_tokens thinking and end without an answer, and the runner still exits 0
    if test "$rc" -eq 0; and not test -s $outfile
        set rc 1
        printf '  %s FAILED: the model returned no answer | %ds -> %s\n' $label $total $dest >&2
        printf '    A reasoning model may have used up max_tokens thinking: raise maxTokens for the model in the runner config, rerun, or pick another model.\n' >&2
        test -s $errlog; and cat $errlog >&2
    else if test "$rc" -eq 0
        printf '  %s done | %ds | %s lines -> %s\n' $label $total "$lines" $dest >&2
    else
        printf '  %s FAILED (rc %s) | %ds -> %s\n' $label "$rc" $total $dest >&2
        test -s $errlog; and cat $errlog >&2
    end
    # A non-empty sidecar means the model reasoned — point at it; an empty one means it
    # didn't (or wasn't a thinking model) — drop it so no stray files accumulate.
    set -l thinking_bytes 0
    if test -n "$sidecar"
        if test -s "$sidecar"
            set thinking_bytes (wc -c <$sidecar | string trim)
            printf '  ↳ reasoning -> %s\n' $sidecar >&2
        else
            rm -f "$sidecar"
        end
    end
    # The run's cost goes into the report itself, so comparing toolkit versions or models
    # later needs nothing but the files. An HTML comment: invisible when the markdown is
    # rendered, one grep away otherwise. Not for a temp that is printed to the terminal.
    # Exact counts when the driver reported them (native ollama and OpenAI drivers), the
    # prompt-size estimate otherwise (runners, claude).
    if test "$rc" -eq 0; and test -s $outfile; and test "$dest" != "(terminal)"
        set -l cost (jq -r '[
            "prompt \(.prompt_tokens) tokens",
            "completion \(.completion_tokens) tokens"
                + (if (.completion_tokens_details.reasoning_tokens // 0) > 0
                   then " (reasoning \(.completion_tokens_details.reasoning_tokens))" else "" end),
            (if .tok_s then "\(.tok_s) tok/s" else empty end),
            (if .cost then "cost \(.cost * 10000 | round / 10000)" else empty end)
            ] | join(" | ")' $ufile 2>/dev/null)
        test -n "$cost"; or set cost "prompt ~"(math "round($tokens / 1000)")"k tokens (estimate)"
        printf '\n<!-- %s | %ds | %s | thinking %d bytes -->\n' \
            $label $total "$cost" $thinking_bytes >>$outfile
    end
    rm -f $errlog $pfile $ufile
    return $rc
end
