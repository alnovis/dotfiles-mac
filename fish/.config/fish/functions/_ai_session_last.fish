function _ai_session_last --description "Resolve .last pointer (project walk-up, then global). Outputs session NAME; empty if none."
    set -l dir $PWD
    while true
        if test "$dir" = "$HOME"; or test "$dir" = /
            break
        end
        if test -f "$dir/.ai/sessions/.last"
            set -l name (cat "$dir/.ai/sessions/.last")
            if test -n "$name"; and test -f "$dir/.ai/sessions/$name.jsonl"
                echo $name
                return 0
            end
        end
        if test -d "$dir/.git"
            break
        end
        set dir (dirname $dir)
    end

    if test -f ~/.config/ai/sessions/.last
        set -l name (cat ~/.config/ai/sessions/.last)
        if test -n "$name"; and test -f ~/.config/ai/sessions/$name.jsonl
            echo $name
            return 0
        end
    end

    return 1
end
