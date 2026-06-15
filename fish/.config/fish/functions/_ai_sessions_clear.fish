function _ai_sessions_clear --description "Wipe messages from session NAME, keep meta"
    argparse 'f/force' -- $argv; or return 1

    set -l name $argv[1]
    if test -z "$name"
        set_color red
        echo "Error: name required — ai sessions clear NAME [--force]"
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

    if not set -q _flag_force
        set_color yellow
        printf "Clear all messages from '%s' (meta retained)? [y/N] " $name
        set_color normal
        read -l confirm
        if test "$confirm" != y; and test "$confirm" != Y
            echo "Cancelled."
            return 0
        end
    end

    # Keep first line (meta), drop rest
    set -l tmp (mktemp)
    head -1 $file >$tmp
    mv $tmp $file

    set_color green
    echo "Cleared messages: $name (meta kept)"
    set_color normal
end
