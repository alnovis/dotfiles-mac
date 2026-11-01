function _ai_verdict_counts --description "Verdict counts of a verify file, counted from its tags: '5 confirmed, 7 refuted[, N uncertain]'" --argument-names file
    # Counted here, not read from the model's own "Verify: X confirmed…" line: on a joined
    # three-run review qwen3.8 summed 12 verdicts as 4 + 6.
    test -s "$file"; or return 1
    set -l c (string match -r -a -- '\[CONFIRMED' <$file | count)
    set -l r (string match -r -a -- '\[REFUTED' <$file | count)
    set -l u (string match -r -a -- '\[UNCERTAIN' <$file | count)
    set -l out "$c confirmed, $r refuted"
    test $u -gt 0; and set out "$out, $u uncertain"
    echo $out
end
