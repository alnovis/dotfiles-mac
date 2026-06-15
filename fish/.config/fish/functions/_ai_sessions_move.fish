function _ai_sessions_move --description "Move session NAME between project and global scope"
    argparse 'to=' -- $argv; or return 1

    set -l name $argv[1]
    if test -z "$name"; or test -z "$_flag_to"
        set_color red
        echo "Error: ai sessions move NAME --to {project|global}"
        set_color normal
        return 1
    end

    if test "$_flag_to" != project; and test "$_flag_to" != global
        set_color red
        echo "Error: --to must be 'project' or 'global'"
        set_color normal
        return 1
    end

    set -l src (_ai_session_file $name)
    if test -z "$src"
        set_color red
        echo "Error: session '$name' not found"
        set_color normal
        return 1
    end

    set -l target_dir
    if test "$_flag_to" = global
        set target_dir ~/.config/ai/sessions
    else
        set -l root (git rev-parse --show-toplevel 2>/dev/null)
        if test -z "$root"
            set_color red
            echo "Error: --to project requires a git repo (current PWD has no git root)"
            set_color normal
            return 1
        end
        set target_dir $root/.ai/sessions
    end

    mkdir -p $target_dir
    set -l target $target_dir/$name.jsonl

    if test "$src" = "$target"
        echo "Already in $_flag_to scope: $src"
        return 0
    end

    if test -f $target
        set_color red
        echo "Error: target exists: $target"
        set_color normal
        return 1
    end

    mv $src $target

    # Move .last pointer if it was pointing at this name in source dir
    set -l src_dir (dirname $src)
    if test -f $src_dir/.last; and test (cat $src_dir/.last) = "$name"
        rm -f $src_dir/.last
        echo $name >$target_dir/.last
    end

    set_color green
    echo "Moved: $name → $_flag_to ($target)"
    set_color normal
end
