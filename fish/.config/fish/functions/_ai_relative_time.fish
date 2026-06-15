function _ai_relative_time --description "Format ISO8601 timestamp as 'Nh ago' / 'Nd ago' / date" --argument-names ts
    set -l then (date -j -f "%Y-%m-%dT%H:%M:%SZ" "$ts" +%s 2>/dev/null)
    if test -z "$then"
        echo "?"
        return
    end
    set -l now (date +%s)
    set -l diff (math -s0 $now - $then)

    if test $diff -lt 60
        echo "$diff""s ago"
    else if test $diff -lt 3600
        echo (math -s0 $diff / 60)"m ago"
    else if test $diff -lt 86400
        echo (math -s0 $diff / 3600)"h ago"
    else if test $diff -lt 604800
        echo (math -s0 $diff / 86400)"d ago"
    else
        string sub --length 10 -- $ts
    end
end
