function _k_pf --description "k pf: port-forward to a pod matched by name substring"
    argparse 'h/help' 'n/namespace=' -- $argv; or return 1

    if set -q _flag_help
        echo "Usage: k pf [OPTIONS] POD_SUBSTRING PORT"
        echo ""
        echo "Port-forward to the pod whose name contains POD_SUBSTRING."
        echo "PORT is LOCAL:REMOTE, or a single port used for both sides."
        echo ""
        echo "Options:"
        echo "  -n, --namespace=NS   Restrict the pod search to a namespace"
        echo "  -h, --help           Show this help"
        echo ""
        echo "Examples:"
        echo "  k pf kafka 9092          localhost:9092 → pod:9092"
        echo "  k pf clickhouse 8123:8123"
        return 0
    end

    set -l substr $argv[1]
    set -l port $argv[2]
    if test -z "$substr" -o -z "$port"
        echo "k pf: need POD_SUBSTRING and PORT (see -h)" >&2
        return 1
    end

    if not string match -q '*:*' -- $port
        set port "$port:$port"
    end

    set -l resolved (_k_resolve_pod $substr $_flag_namespace); or return 1
    set -l parts (string split \t -- $resolved)
    set -l ns $parts[1]
    set -l pod $parts[2]

    set_color cyan
    echo "Port-forward $port → $pod  ($ns)"
    set_color normal
    echo "---"
    kubectl port-forward -n $ns $pod $port
end
