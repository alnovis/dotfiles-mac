function dlogs --description "Docker compose logs with optional service filter and grep"
    argparse 'g/grep=' 'n/lines=' -- $argv; or return 1

    set -l lines 100
    if set -q _flag_lines
        set lines $_flag_lines
    end

    set -l service $argv[1]

    # Build command
    set -l cmd docker compose logs -f --tail=$lines
    if test -n "$service"
        set -a cmd $service
    end

    echo "Docker logs"
    if test -n "$service"
        set_color cyan
        echo "Service: $service"
        set_color normal
    end
    if set -q _flag_grep
        set_color yellow
        echo "Filter: $_flag_grep"
        set_color normal
    end
    echo "---"

    if set -q _flag_grep
        $cmd 2>&1 | grep --color=always -i "$_flag_grep"
    else
        $cmd
    end
end
