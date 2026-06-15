function _ai_sessions_unpin --description "Remove pin from session NAME" --argument-names name
    if test -z "$name"
        set_color red
        echo "Error: name required — ai sessions unpin NAME"
        set_color normal
        return 1
    end

    set -l file (_ai_session_file $name)
    if test -z "$file"
        set_color red
        echo "Error: session '$name' not found"
        set_color normal
        return 1
    end

    set -l now (date -u +"%Y-%m-%dT%H:%M:%SZ")
    jq -nc --arg ts "$now" '{t:"config", pinned:false, ts:$ts}' >>$file

    set_color green
    echo "Unpinned: $name"
    set_color normal
end
