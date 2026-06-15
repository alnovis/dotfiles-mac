function _ai_sessions_stats --description "Aggregated stats across sessions: counts, tokens, models"
    argparse 'a/all' 'archived' -- $argv; or return 1

    set -l include_archived 0
    set -q _flag_archived; and set include_archived 1
    set -q _flag_all; and set include_archived 1

    set -l dirs

    set -l dir $PWD
    while true
        if test "$dir" = "$HOME"; or test "$dir" = /
            break
        end
        if test -d "$dir/.ai/sessions"
            set -a dirs "$dir/.ai/sessions"
            if test $include_archived -eq 1; and test -d "$dir/.ai/sessions/archived"
                set -a dirs "$dir/.ai/sessions/archived"
            end
            break
        end
        if test -d "$dir/.git"
            break
        end
        set dir (dirname $dir)
    end

    if test -d ~/.config/ai/sessions
        set -a dirs ~/.config/ai/sessions
        if test $include_archived -eq 1; and test -d ~/.config/ai/sessions/archived
            set -a dirs ~/.config/ai/sessions/archived
        end
    end

    set -l active 0
    set -l archived 0
    set -l total_turns 0
    set -l tok_in_total 0
    set -l tok_out_total 0
    set -l oldest_ts
    set -l oldest_unix
    set -l newest_ts
    set -l newest_unix
    set -l model_lines

    for d in $dirs
        set -l is_archived 0
        if string match -q "*/archived" $d
            set is_archived 1
        end

        for file in $d/*.jsonl
            test -f $file; or continue

            if test $is_archived -eq 1
                set archived (math $archived + 1)
            else
                set active (math $active + 1)
            end

            # Raw output (-sr) so values aren't JSON-quoted
            set -l line (jq -sr '
                ([.[] | select(.t == "assistant")]) as $a |
                {
                    turns: ($a | length),
                    in: ([$a[].usage.prompt_eval_count // 0] | add // 0),
                    out: ([$a[].usage.eval_count // 0] | add // 0),
                    created: (first(.[] | select(.t == "meta")).created // ""),
                    last: ($a[-1].ts // ""),
                    models: ([$a[].model // empty])
                } | "\(.turns)|\(.in)|\(.out)|\(.created)|\(.last)|\(.models | join(","))"
            ' $file 2>/dev/null)

            set -l p (string split "|" $line)
            set total_turns (math $total_turns + $p[1])
            set tok_in_total (math $tok_in_total + $p[2])
            set tok_out_total (math $tok_out_total + $p[3])

            set -l created $p[4]
            set -l last $p[5]
            set -l models_str $p[6]

            if test -n "$created"
                set -l u (date -j -f "%Y-%m-%dT%H:%M:%SZ" "$created" +%s 2>/dev/null)
                if test -n "$u"
                    if test -z "$oldest_unix"; or test $u -lt $oldest_unix
                        set oldest_ts $created
                        set oldest_unix $u
                    end
                end
            end
            if test -n "$last"
                set -l u (date -j -f "%Y-%m-%dT%H:%M:%SZ" "$last" +%s 2>/dev/null)
                if test -n "$u"
                    if test -z "$newest_unix"; or test $u -gt $newest_unix
                        set newest_ts $last
                        set newest_unix $u
                    end
                end
            end

            if test -n "$models_str"
                for m in (string split "," $models_str)
                    test -n "$m"; and set -a model_lines $m
                end
            end
        end
    end

    set -l total (math $active + $archived)
    set -l tok_total (math $tok_in_total + $tok_out_total)

    set_color cyan
    echo "Sessions stats"
    set_color normal
    set -l arch_str ""
    test $include_archived -eq 1; and set arch_str ", $archived archived"
    echo "  Total:        $total ($active active$arch_str)"
    echo "  Total turns:  $total_turns assistant"
    echo "  Tokens:       $tok_in_total input / $tok_out_total output  ($tok_total total)"
    if test -n "$oldest_ts"; and test -n "$newest_ts"
        echo "  Activity:     oldest "(_ai_relative_time $oldest_ts)" — newest "(_ai_relative_time $newest_ts)
    end

    if test (count $model_lines) -gt 0
        echo
        set_color cyan
        echo "Models used (by turn count):"
        set_color normal
        printf '%s\n' $model_lines | sort | uniq -c | sort -rn | while read -l line
            set -l trimmed (string trim $line)
            set -l p (string split -n " " $trimmed)
            printf "  %-30s %s turns\n" $p[2] $p[1]
        end
    end

    if test $include_archived -eq 0
        echo
        set_color brblack
        echo "(use --all to include archived)"
        set_color normal
    end
end
