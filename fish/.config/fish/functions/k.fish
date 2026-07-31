function k --description "kubectl toolkit: pods, log, sh, desc, ns, pf — or transparent kubectl"
    set -l sub $argv[1]

    if test (count $argv) -eq 0; or contains -- "$sub" help --help -h
        _k_help
        return
    end

    set -lx KUBECONFIG (_k_kubeconfig)

    # k <sub> [args...] → _k_<sub> args...  (smart helpers on short verbs)
    if contains -- "$sub" pods log sh desc ns pf
        _k_$sub $argv[2..]
        return
    end

    # Anything else → transparent kubectl (get, apply, logs, describe, exec, ...)
    command kubectl $argv
end

function _k_help
    echo "Usage: k [COMMAND] [ARGS...]"
    echo
    echo "kubectl toolkit for the local k3s cluster."
    echo "Known COMMANDs are smart helpers; anything else is passed to kubectl."
    echo
    echo "Helpers:"
    echo "  pods [NS]                Pod overview; problems highlighted (default: all ns)"
    echo "  log  <pod> [OPTS]        Tail logs by name substring (-f -g -t -p -c -n)"
    echo "  sh   <pod> [CMD]         Exec a shell (or command) in a pod"
    echo "  desc <pod>               Describe pod + its recent events"
    echo "  ns   [NAME]              Show namespaces, or switch the default"
    echo "  pf   <pod> <PORT>        Port-forward (PORT = LOCAL:REMOTE or single)"
    echo
    echo "Pod arguments match by name SUBSTRING across namespaces (-n to scope)."
    echo "Each helper takes -h for its own options."
    echo
    echo "Passthrough (raw kubectl, full verb names):"
    echo "  k get pods -A            k apply -f manifest.yaml"
    echo "  k logs <full-pod-name>   k describe deploy/foo    k exec ..."
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
end
