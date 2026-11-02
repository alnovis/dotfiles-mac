function _ai_verdict_counts --description "Verdict counts of a verify file, counted from its tags: '5 confirmed, 7 refuted[, N uncertain]'" --argument-names file
    # Counted here, not read from the model's own "Verify: X confirmed…" line: on a joined
    # three-run review qwen3.8 summed 12 verdicts as 4 + 6.
    # A verdict is "[REFUTED 8/10]" — or, when the model drops the brackets, "— REFUTED 8/10"
    # at the end of the finding's line. Bare words only there: a why: line may say "not REFUTED".
    test -s "$file"; or return 1
    set -l n
    for v in CONFIRMED REFUTED UNCERTAIN
        set -l tagged (string match -r -a -- "\[$v" <$file | count)
        set -l bare (string match -r -- "[—–-]\s*\**\s*$v(?:\s+\d+\s*/\s*10)?\s*\**\s*\$" <$file | count)
        set -a n (math $tagged + $bare)
    end
    set -l out "$n[1] confirmed, $n[2] refuted"
    test $n[3] -gt 0; and set out "$out, $n[3] uncertain"
    echo $out
end
