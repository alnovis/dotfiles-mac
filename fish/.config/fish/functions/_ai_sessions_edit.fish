function _ai_sessions_edit --description "Open session NAME in \$EDITOR (raw JSONL — be careful)" --argument-names name
    if test -z "$name"
        set_color red
        echo "Error: name required — ai sessions edit NAME"
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

    set -l editor
    for c in $EDITOR $VISUAL nvim vim
        test -z "$c"; and continue
        set -l prog (string split ' ' $c)[1]
        if command -q $prog
            set editor $c
            break
        end
    end
    if test -z "$editor"
        set_color red
        echo "Error: no editor found (set \$EDITOR or install nvim/vim)" >&2
        set_color normal
        return 1
    end
    $editor $file
end
