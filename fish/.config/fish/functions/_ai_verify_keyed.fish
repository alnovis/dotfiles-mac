function _ai_verify_keyed --description "How many verdicts of a verify file are keyed by a finding number ([F3] … [CONFIRMED 8/10]): the ones the majority vote can count" --argument-names file
    # A run can answer and still give the vote nothing: qwen3.6 wrote "F4 (Confirmed) — …",
    # no [F4], no tag, and the vote said "only 1 of 3 runs judged it" on every finding while
    # the summary said "2/3 answered". A verdict as _ai_verdict_counts reads it, on a line
    # that carries the finding's [Fn].
    test -s "$file"; or begin
        echo 0
        return 0
    end
    string match -r -- '\[F[0-9]+\].*(?:\[(?:CONFIRMED|REFUTED|UNCERTAIN)|[—–-]\s*\**\s*(?:CONFIRMED|REFUTED|UNCERTAIN)(?:\s+\d+\s*/\s*10)?\s*\**\s*$)' <$file | count
end
