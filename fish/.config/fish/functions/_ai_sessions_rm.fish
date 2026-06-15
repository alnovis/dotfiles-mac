function _ai_sessions_rm --description "Delete session NAME"
    argparse 'f/force' -- $argv; or return 1

    set -l name $argv[1]
    if test -z "$name"
        set_color red
        echo "Error: session name required — ai sessions rm NAME [--force]"
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
        printf "Delete session '%s' (%s)? [y/N] " $name $file
        set_color normal
        read -l confirm
        if test "$confirm" != y; and test "$confirm" != Y
            echo "Cancelled."
            return 0
        end
    end

    rm -f $file

    # If this was the .last in its dir, clear pointer
    set -l dir (dirname $file)
    if test -f $dir/.last; and test (cat $dir/.last) = "$name"
        rm -f $dir/.last
    end

    set_color green
    echo "Deleted: $file"
    set_color normal
end
