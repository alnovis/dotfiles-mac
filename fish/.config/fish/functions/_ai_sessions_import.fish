function _ai_sessions_import --description "Import a session JSONL from PATH into project or global"
    argparse 'name=' 'global' -- $argv; or return 1

    set -l path $argv[1]
    if test -z "$path"
        set_color red
        echo "Error: path required — ai sessions import PATH [--name NEW] [--global]"
        set_color normal
        return 1
    end

    if not test -f $path
        set_color red
        echo "Error: file not found: $path"
        set_color normal
        return 1
    end

    # Validate: first line should be a meta record
    set -l first (head -1 $path)
    set -l first_t (echo $first | jq -r '.t // empty' 2>/dev/null)
    if test "$first_t" != meta
        set_color red
        echo "Error: file does not start with a meta record — not a valid session JSONL"
        set_color normal
        return 1
    end

    set -l existing_name (echo $first | jq -r '.name // empty')
    set -l name $_flag_name
    test -z "$name"; and set name $existing_name
    test -z "$name"; and set name (basename $path .jsonl)

    set -l scope ""
    set -q _flag_global; and set scope global
    set -l target (_ai_session_target $name $scope)

    if test -f $target
        set_color red
        echo "Error: session '$name' already exists at $target"
        set_color normal
        echo "Use --name NEW to import under a different name."
        return 1
    end

    mkdir -p (dirname $target)

    # If name differs from file's existing name, rewrite meta
    if test "$name" != "$existing_name"
        set -l now (date -u +"%Y-%m-%dT%H:%M:%SZ")
        set -l tmp (mktemp)
        echo $first | jq -c --arg n "$name" --arg ts "$now" '. + {name:$n, updated:$ts, imported_from:.name}' >$tmp
        tail -n +2 $path >>$tmp
        mv $tmp $target
    else
        cp $path $target
    end

    set_color green
    echo "Imported: $name → $target"
    set_color normal
end
