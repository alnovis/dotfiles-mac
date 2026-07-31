function _k_log --description "k log: tail logs from a pod matched by name substring"
    argparse 'h/help' 'f/follow' 'g/grep=' 't/tail=' 'p/previous' 'c/container=' 'n/namespace=' -- $argv; or return 1

    if set -q _flag_help
        echo "Usage: k log [OPTIONS] POD_SUBSTRING"
        echo ""
        echo "Tail logs from the pod whose name contains POD_SUBSTRING."
        echo ""
        echo "Options:"
        echo "  -f, --follow         Stream new log lines"
        echo "  -g, --grep=PATTERN   Filter output by pattern (case-insensitive)"
        echo "  -t, --tail=N         Number of tail lines (default: 100)"
        echo "  -p, --previous       Logs from the previous container instance (crashes)"
        echo "  -c, --container=NAME Pick a container (default: all containers, prefixed)"
        echo "  -n, --namespace=NS   Restrict the pod search to a namespace"
        echo "  -h, --help           Show this help"
        echo ""
        echo "Examples:"
        echo "  k log kafka               Logs from the pod matching 'kafka'"
        echo "  k log api -f -g ERROR     Follow api logs, filter for ERROR"
        echo "  k log worker -p           Previous instance's logs (why it crashed)"
        return 0
    end

    set -l substr $argv[1]
    if test -z "$substr"
        echo "k log: missing POD_SUBSTRING (see -h)" >&2
        return 1
    end

    set -l resolved (_k_resolve_pod $substr $_flag_namespace); or return 1
    set -l parts (string split \t -- $resolved)
    set -l ns $parts[1]
    set -l pod $parts[2]

    set -l tail 100
    if set -q _flag_tail
        set tail $_flag_tail
    end

    set -l cmd kubectl logs -n $ns $pod --tail=$tail
    set -q _flag_follow; and set -a cmd -f
    set -q _flag_previous; and set -a cmd -p
    if set -q _flag_container
        set -a cmd -c $_flag_container
    else
        set -a cmd --all-containers=true --prefix
    end

    echo "Pod logs"
    set_color cyan
    echo "Pod: $pod  ($ns)"
    set_color normal
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
