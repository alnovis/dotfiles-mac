function _ai_sessions_export --description "Export session NAME (md|json|jsonl) to PATH or stdout"
    argparse 'f/format=' -- $argv; or return 1

    set -l name $argv[1]
    set -l out $argv[2]

    if test -z "$name"
        set_color red
        echo "Error: name required — ai sessions export NAME [--format md|json|jsonl] [PATH]"
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

    set -l format $_flag_format
    test -z "$format"; and set format md

    set -l content
    switch $format
        case md
            set content (_ai_sessions_show $name | string collect)
        case json
            set content (jq -s '.' $file | string collect)
        case jsonl raw
            set content (cat $file | string collect)
        case '*'
            set_color red
            echo "Error: unknown format '$format' (md|json|jsonl)" >&2
            set_color normal
            return 1
    end

    if test -z "$out"
        echo $content
    else
        echo $content >$out
        set_color green
        echo "Exported: $out"
        set_color normal
    end
end
