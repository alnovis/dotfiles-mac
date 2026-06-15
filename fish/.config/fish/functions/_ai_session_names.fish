function _ai_session_names --description "List all session names from project (walk-up nearest) + global"
    set -l dirs

    # Walk-up: nearest .ai/sessions/ dir in tree
    set -l dir $PWD
    while true
        if test "$dir" = "$HOME"; or test "$dir" = /
            break
        end
        if test -d "$dir/.ai/sessions"
            set -a dirs "$dir/.ai/sessions"
            break
        end
        if test -d "$dir/.git"
            break
        end
        set dir (dirname $dir)
    end

    # Global
    if test -d ~/.config/ai/sessions
        set -a dirs ~/.config/ai/sessions
    end

    for d in $dirs
        for f in $d/*.jsonl
            if test -f $f
                basename $f .jsonl
            end
        end
    end | sort -u
end
