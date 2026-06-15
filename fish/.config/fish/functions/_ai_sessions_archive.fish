function _ai_sessions_archive --description "Move session NAME to archived/ subdir (hidden from default ls)" --argument-names name
    if test -z "$name"
        set_color red
        echo "Error: name required — ai sessions archive NAME"
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

    set -l dir (dirname $file)
    set -l archived_dir $dir/archived
    mkdir -p $archived_dir

    set -l target $archived_dir/$name.jsonl
    if test -f $target
        set_color red
        echo "Error: archive target already exists: $target"
        set_color normal
        return 1
    end

    mv $file $target

    # Clear .last if it pointed at this session
    if test -f $dir/.last; and test (cat $dir/.last) = "$name"
        rm -f $dir/.last
    end

    set_color green
    echo "Archived: $name → $target"
    set_color normal
end
