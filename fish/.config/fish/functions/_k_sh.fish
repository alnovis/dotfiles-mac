function _k_sh --description "k sh: exec a shell (or command) in a pod matched by substring"
    argparse 'h/help' 'n/namespace=' 'c/container=' -- $argv; or return 1

    if set -q _flag_help
        echo "Usage: k sh [OPTIONS] POD_SUBSTRING [COMMAND...]"
        echo ""
        echo "Exec into the pod whose name contains POD_SUBSTRING."
        echo "With no COMMAND, opens an interactive shell (bash if present, else sh)."
        echo ""
        echo "Options:"
        echo "  -c, --container=NAME  Target a specific container"
        echo "  -n, --namespace=NS    Restrict the pod search to a namespace"
        echo "  -h, --help            Show this help"
        echo ""
        echo "Examples:"
        echo "  k sh kafka                 Interactive shell in the kafka pod"
        echo "  k sh api env               Run 'env' in the api pod"
        echo "  k sh worker -c sidecar     Shell into the sidecar container"
        return 0
    end

    set -l substr $argv[1]
    if test -z "$substr"
        echo "k sh: missing POD_SUBSTRING (see -h)" >&2
        return 1
    end
    set -l cmd_args $argv[2..-1]

    set -l resolved (_k_resolve_pod $substr $_flag_namespace); or return 1
    set -l parts (string split \t -- $resolved)
    set -l ns $parts[1]
    set -l pod $parts[2]

    set -l base kubectl exec -it -n $ns $pod
    set -q _flag_container; and set -a base -c $_flag_container

    if test (count $cmd_args) -gt 0
        $base -- $cmd_args
    else
        set_color cyan
        echo "Shell → $pod  ($ns)"
        set_color normal
        $base -- sh -c 'command -v bash >/dev/null 2>&1 && exec bash || exec sh'
    end
end
