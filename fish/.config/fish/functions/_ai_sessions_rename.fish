function _ai_sessions_rename --description "Rename session OLD to NEW (within the same dir)" --argument-names old new
    if test -z "$old"; or test -z "$new"
        set_color red
        echo "Error: ai sessions rename OLD NEW"
        set_color normal
        return 1
    end

    set -l old_file (_ai_session_file $old)
    if test -z "$old_file"
        set_color red
        echo "Error: session '$old' not found"
        set_color normal
        return 1
    end

    set -l dir (dirname $old_file)
    set -l new_file $dir/$new.jsonl

    if test -f $new_file
        set_color red
        echo "Error: session '$new' already exists at $new_file"
        set_color normal
        return 1
    end

    mv $old_file $new_file

    # Update meta.name field in the file (first line)
    set -l tmp (mktemp)
    awk -v new="$new" 'NR==1{
        sub(/"name":"[^"]*"/, "\"name\":\"" new "\"")
    }{print}' $new_file >$tmp && mv $tmp $new_file

    # Update .last pointer if it pointed at OLD
    if test -f $dir/.last; and test (cat $dir/.last) = "$old"
        echo $new >$dir/.last
    end

    set_color green
    echo "Renamed: $old → $new"
    set_color normal
end
