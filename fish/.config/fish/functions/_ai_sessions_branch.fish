function _ai_sessions_branch --description "Fork session SRC into NEW (auto-named SRC-branch-N if NEW omitted), same scope" --argument-names src new
    if test -z "$src"
        set_color red
        echo "Error: source name required — ai sessions branch SRC [NEW]"
        set_color normal
        return 1
    end

    set -l src_file (_ai_session_file $src)
    if test -z "$src_file"
        set_color red
        echo "Error: session '$src' not found"
        set_color normal
        return 1
    end

    set -l dir (dirname $src_file)

    if test -z "$new"
        set -l n 1
        while test -f "$dir/$src-branch-$n.jsonl"
            set n (math $n + 1)
        end
        set new "$src-branch-$n"
    end

    set -l new_file $dir/$new.jsonl
    if test -f $new_file
        set_color red
        echo "Error: session '$new' already exists at $new_file"
        set_color normal
        return 1
    end

    set -l now (date -u +"%Y-%m-%dT%H:%M:%SZ")

    # Rewrite meta on first line, keep rest unchanged
    set -l tmp (mktemp)
    jq -nc --arg name "$new" --arg ts "$now" --arg from "$src" \
        '{t:"meta", name:$name, created:$ts, updated:$ts, branched_from:$from}' >$tmp
    tail -n +2 $src_file >>$tmp
    mv $tmp $new_file

    set_color green
    echo "Branched: $src → $new"
    echo "  Path: $new_file"
    set_color normal
end
