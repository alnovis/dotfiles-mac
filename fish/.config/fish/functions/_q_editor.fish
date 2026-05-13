function _q_editor --description "Resolve editor: \$EDITOR → \$VISUAL → nvim → vim"
    for candidate in $EDITOR $VISUAL nvim vim
        if test -z "$candidate"
            continue
        end
        # Extract program name (strip args like "code -w")
        set -l prog (string split ' ' $candidate)[1]
        if command -q $prog
            echo $candidate
            return 0
        end
    end

    set_color red
    echo "Error: no editor found (set \$EDITOR or install nvim/vim)" >&2
    set_color normal
    return 1
end
