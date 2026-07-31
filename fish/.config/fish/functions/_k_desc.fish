function _k_desc --description "k desc: describe a pod and show its recent events"
    argparse 'h/help' 'n/namespace=' -- $argv; or return 1

    if set -q _flag_help
        echo "Usage: k desc [OPTIONS] POD_SUBSTRING"
        echo ""
        echo "Describe the pod whose name contains POD_SUBSTRING, then list its"
        echo "recent events — the go-to view for 'why won't this pod come up?'."
        echo ""
        echo "Options:"
        echo "  -n, --namespace=NS   Restrict the pod search to a namespace"
        echo "  -h, --help           Show this help"
        return 0
    end

    set -l substr $argv[1]
    if test -z "$substr"
        echo "k desc: missing POD_SUBSTRING (see -h)" >&2
        return 1
    end

    set -l resolved (_k_resolve_pod $substr $_flag_namespace); or return 1
    set -l parts (string split \t -- $resolved)
    set -l ns $parts[1]
    set -l pod $parts[2]

    kubectl describe pod -n $ns $pod

    echo ""
    set_color cyan
    echo "--- Recent events ($pod) ---"
    set_color normal
    set -l events (kubectl get events -n $ns --field-selector involvedObject.name=$pod --sort-by=.lastTimestamp 2>/dev/null)
    if test (count $events) -le 1
        echo "No events"
    else
        printf '%s\n' $events | tail -n 16
    end
end
