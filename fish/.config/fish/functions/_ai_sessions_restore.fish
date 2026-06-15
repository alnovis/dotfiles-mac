function _ai_sessions_restore --description "Restore archived session NAME back to active" --argument-names name
    if test -z "$name"
        set_color red
        echo "Error: name required — ai sessions restore NAME"
        set_color normal
        return 1
    end

    # Find in archived/ — walk up project + global
    set -l archived
    set -l dir $PWD
    while true
        if test "$dir" = "$HOME"; or test "$dir" = /
            break
        end
        if test -f "$dir/.ai/sessions/archived/$name.jsonl"
            set archived "$dir/.ai/sessions/archived/$name.jsonl"
            break
        end
        if test -d "$dir/.git"
            break
        end
        set dir (dirname $dir)
    end
    if test -z "$archived"; and test -f ~/.config/ai/sessions/archived/$name.jsonl
        set archived ~/.config/ai/sessions/archived/$name.jsonl
    end

    if test -z "$archived"
        set_color red
        echo "Error: archived session '$name' not found"
        set_color normal
        return 1
    end

    set -l active_dir (dirname (dirname $archived))
    set -l target $active_dir/$name.jsonl

    if test -f $target
        set_color red
        echo "Error: active session with same name already exists: $target"
        set_color normal
        echo "Rename or delete it first."
        return 1
    end

    mv $archived $target

    # Remove archived/ if empty
    rmdir (dirname $archived) 2>/dev/null

    set_color green
    echo "Restored: $name → $target"
    set_color normal
end
