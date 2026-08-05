function k --description "kubectl toolkit: pods, log, sh, desc, ns, pf; 'k x' for raw kubectl"
    set -l sub $argv[1]

    if test (count $argv) -eq 0; or contains -- "$sub" help --help -h
        _k_help
        return
    end

    set -lx KUBECONFIG (_k_kubeconfig)

    # Raw kubectl escape hatch (KUBECONFIG baked in).
    if test "$sub" = x
        command kubectl $argv[2..]
        return
    end

    # Smart helpers — each a closed subcommand with its own --help and flags.
    if contains -- "$sub" pods log sh desc ns pf
        _k_$sub $argv[2..]
        return
    end

    echo "k: unknown command '$sub'" >&2
    echo "Try 'k help', or 'k x $argv' to run it through raw kubectl." >&2
    return 1
end

function _k_help
    echo "Usage: k <command> [ARGS...]"
    echo
    echo "kubectl toolkit for the local k3s cluster — a closed set of helpers,"
    echo "plus 'k x' for raw kubectl. Each command has its own -h/--help."
    echo
    echo "Commands:"
    echo "  pods [NS]                Pod overview; problems highlighted (default: all ns)"
    echo "  log  <pod> [OPTS]        Tail logs by name substring (-f -g -t -p -c -n)"
    echo "  sh   <pod> [CMD]         Exec a shell (or command) in a pod"
    echo "  desc <pod>               Describe pod + its recent events"
    echo "  ns   [NAME]              Show namespaces, or switch the default"
    echo "  pf   <pod> <PORT>        Port-forward (PORT = LOCAL:REMOTE or single)"
    echo "  x    <args...>           Raw kubectl with KUBECONFIG baked in"
    echo "  help                     Show this help"
    echo
    echo "Pod arguments match by name SUBSTRING across namespaces (-n to scope)."
    echo
    echo "Examples:"
    echo "  k pods                   All pods, problems highlighted"
    echo "  k pods kafka             Only the kafka namespace"
    echo "  k log kafka -f -g ERROR  Follow kafka logs, filter ERROR"
    echo "  k log worker -p          Previous instance's logs (crash loop)"
    echo "  k sh clickhouse          Interactive shell in the clickhouse pod"
    echo "  k desc kafka             Describe + events (why won't it come up?)"
    echo "  k ns loadtest            Switch default namespace"
    echo "  k pf clickhouse 8123     localhost:8123 → pod:8123"
    echo "  k x apply -f manifest.yaml   Raw kubectl (full verb + flag completion)"
    echo "  k x get pods -A              Raw kubectl"
end
