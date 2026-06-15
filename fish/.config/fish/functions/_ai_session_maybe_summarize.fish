function _ai_session_maybe_summarize --description "If session FILE exceeds token threshold and has more than recent-turns worth of uncovered turns, generate summary and append to FILE" --argument-names file model
    if not test -f $file
        return 0
    end

    set -l recent (_ai_config_read sessions_recent_turns 2>/dev/null)
    test -z "$recent"; and set recent 10
    set -l threshold (_ai_config_read sessions_token_threshold 2>/dev/null)
    test -z "$threshold"; and set threshold 0.7
    set -l ctx (_ai_context_window $model)
    set -l budget (math -s0 "$ctx * $threshold")

    # Which model to use for summarization (default = same as session)
    set -l summary_model (_ai_config_read sessions_summary_model 2>/dev/null)
    test -z "$summary_model"; and set summary_model $model

    set -l all (jq -sc '.' $file)

    # How many turn messages are already covered by past summaries
    set -l covered (echo $all | jq '[.[] | select(.t == "summary") | .covers // 0] | max // 0')
    test -z "$covered"; or test "$covered" = null; and set covered 0

    set -l head (echo $all | jq -c '[.[] | select(.t == "system" or .t == "summary")]')
    set -l turns_uncovered (echo $all | jq -c --argjson c $covered \
        '[.[] | select(.t == "user" or .t == "assistant")] | .[$c:]')

    # Estimate token usage
    set -l total_chars (printf '%s\n%s\n' $head $turns_uncovered | jq -s '[.[] | .[] | .content // "" | length] | add // 0')
    set -l est_tokens (math -s0 "$total_chars / 3")

    if test $est_tokens -le $budget
        return 0
    end

    set -l uncov_count (echo $turns_uncovered | jq 'length')
    set -l keep_n (math "2 * $recent + 1")

    if test $uncov_count -le $keep_n
        return 0
    end

    set -l to_summarize_count (math "$uncov_count - $keep_n")
    set -l to_summarize_msgs (echo $turns_uncovered | jq -c --argjson n $to_summarize_count \
        '[.[:$n] | .[] | {role: .t, content: .content}]')

    set_color brblack >&2
    echo "[summarizing $to_summarize_count old turns via $summary_model... may take a moment]" >&2
    set_color normal >&2

    set -l t0 (date +%s)
    set -l summary_text (_ai_session_summarize $summary_model $to_summarize_msgs)
    set -l t1 (date +%s)

    if test -z "$summary_text"
        set_color yellow >&2
        echo "[summary failed — falling back to sliding window cut]" >&2
        set_color normal >&2
        return 1
    end

    set -l now (date -u +"%Y-%m-%dT%H:%M:%SZ")
    set -l new_covered (math -s0 "$covered + $to_summarize_count")
    jq -nc --arg c "$summary_text" --arg ts "$now" --argjson cov $new_covered --arg m "$summary_model" \
        '{t:"summary", content:$c, ts:$ts, covers:$cov, model:$m}' >>$file

    set_color brblack >&2
    echo "[summary done in "(math $t1 - $t0)"s — covers turns 1..$new_covered]" >&2
    set_color normal >&2
end
