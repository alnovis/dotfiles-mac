function _ai_session_build_messages --description "Build messages JSON for /api/chat with sliding window truncation. Emits 'ctx_truncated kept=N total=M' to stderr if truncated." --argument-names file model
    set -l recent (_ai_config_read sessions_recent_turns 2>/dev/null)
    test -z "$recent"; and set recent 10
    set -l threshold (_ai_config_read sessions_token_threshold 2>/dev/null)
    test -z "$threshold"; and set threshold 0.7
    set -l ctx (_ai_context_window $model)

    if not test -f $file
        echo "[]"
        return
    end

    # Slurp whole jsonl
    set -l all (jq -sc '.' $file)

    # Turns covered by existing summaries (max .covers across summary records)
    set -l covered (echo $all | jq '[.[] | select(.t == "summary") | .covers // 0] | max // 0')
    test -z "$covered"; or test "$covered" = null; and set covered 0

    # Split into "head" (system + summary) and "turns" (user + assistant minus covered prefix)
    set -l head (echo $all | jq -c '[.[] | select(.t == "system" or .t == "summary")]')
    set -l turns (echo $all | jq -c --argjson c $covered \
        '[.[] | select(.t == "user" or .t == "assistant")] | .[$c:]')

    # Total char count → token estimate (chars/3 conservative)
    set -l total_chars (printf '%s\n%s\n' $head $turns | jq -s '[.[] | .[] | .content // "" | length] | add // 0')
    set -l est_tokens (math -s0 "$total_chars / 3")
    set -l budget (math -s0 "$ctx * $threshold")

    set -l total_turns (echo $turns | jq 'length')
    set -l truncated 0

    if test $est_tokens -gt $budget
        # Sliding window: keep last (2*recent + 1) messages
        # The +1 is for the current pending user message at the tail
        set -l keep_n (math "2 * $recent + 1")
        set turns (echo $turns | jq -c --argjson n $keep_n 'if length > $n then .[-$n:] else . end')
        set truncated 1

        # Aggressive fallback if still over budget (e.g. very long single turn)
        # Drop pairs from the front (keeping the tail / current user) until ≤ budget or only 3 left
        while true
            set -l new_chars (printf '%s\n%s\n' $head $turns | jq -s '[.[] | .[] | .content // "" | length] | add // 0')
            set -l new_est (math -s0 "$new_chars / 3")
            set -l tlen (echo $turns | jq 'length')
            if test $new_est -le $budget
                break
            end
            if test $tlen -le 3
                break
            end
            set turns (echo $turns | jq -c '.[1:]')
        end
    end

    # Compose final messages, mapping summary→system with prefix
    printf '%s\n%s\n' $head $turns | jq -sc '
        [.[] | .[]] | map(
            if .t == "summary" then {role: "system", content: ("Summary of earlier conversation: " + .content)}
            else {role: .t, content: .content}
            end
        )
    '

    if test $truncated -eq 1
        set -l kept (echo $turns | jq 'length')
        echo "ctx_truncated kept=$kept total=$total_turns budget=$budget" >&2
    end
end
