function dlogs --description "Docker compose logs with optional service filter and grep"
    argparse 'h/help' 'g/grep=' 'n/lines=' -- $argv; or return 1

    if set -q _flag_help
        echo "Usage: dlogs [OPTIONS] [SERVICE]"
        echo ""
        echo "Docker compose logs with optional service filter and grep."
        echo ""
        echo "Options:"
        echo "  -g, --grep=PATTERN   Filter output by pattern (case-insensitive)"
        echo "  -n, --lines=N        Number of tail lines (default: 100)"
        echo "  -h, --help           Show this help"
        echo ""
        echo "Examples:"
        echo "  dlogs                    All services, last 100 lines"
        echo "  dlogs api                Only api service"
        echo "  dlogs api -g ERROR       Filter api logs for ERROR"
        echo "  dlogs -n 500 -g timeout  Last 500 lines, filter for timeout"
        return 0
    end

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
