function _ai_session_file --description "Resolve existing session NAME: walk-up for project, then global. Empty if none." --argument-names name
    set -l dir $PWD

    while true
        if test "$dir" = "$HOME"; or test "$dir" = /
            break
        end
        if test -f "$dir/.ai/sessions/$name.jsonl"
            echo "$dir/.ai/sessions/$name.jsonl"
            return 0
        end
        if test -d "$dir/.git"
            break
        end
        set dir (dirname $dir)
    end

    set -l global ~/.config/ai/sessions/$name.jsonl
    if test -f $global
        echo $global
        return 0
    end

    return 1
end
